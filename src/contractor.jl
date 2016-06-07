# Own version of gensym:
const symbol_number = [1]

doc"""Return a new unique symbol like z10"""
function make_symbol()
    i = symbol_number[1]
    symbol_number[1] += 1

    symbol("z", i)
end


function insert_variables(ex)  # numbers are leaves
    ex, Symbol[], quote end
end

function insert_variables(ex::Symbol)  # symbols are leaves
    ex, [ex], quote end
end

doc"""
`insert_variables` recursively replaces operations like `a+b` by assignments of the form `z10 = a+b`, where `z10` is a distinct symbol created using `make_symbol` (like `gensym` but more readable).

Returns: (i) new variable at head of tree
        (ii) variables contained in tree, in sorted order
        (iii) generated code.
"""
function insert_variables(ex::Expr)

    op = ex.args[1]

    # TODO: Use @match here!
    # rewrite +(a,b,c) as +(a,+(b,c))
    if op in (:+, :*) && length(ex.args) > 3
        return insert_variables( :( ($op)($(ex.args[2]), ($op)($(ex.args[3:end]...) )) ))
    end

    new_code = quote end
    current_args = []  # the arguments in the current expression that will be added
    all_vars = Set{Symbol}()  # all variables contained in the sub-expressions

    for arg in ex.args[2:end]
        top, contained_vars, code = insert_variables(arg)

        push!(current_args, top)
        union!(all_vars, contained_vars)
        append!(new_code.args, code.args)  # add previously-generated code
    end

    new_var = make_symbol()

    top_level_code = :($(new_var) = ($op)($(current_args...)))  # new top-level code
    push!(new_code.args, top_level_code)

    return new_var, sort(collect(all_vars)), new_code

end


const rev_ops = Dict(:+ => :plusRev, :* => :mulRev, :^ => :powerRev, :- => :minusRev)

doc"""
`forward_backward` takes in an expression like `x^2 + y^2` and outputs
code for the forward-backward contractor

TODO: Add intersections in forward direction
"""
function forward_backward(ex::Expr, constraint::Interval=entireinterval())

    new_ex = copy(ex)

    root_var = :empty
    all_vars = Symbol[]
    code = quote end


    # Step 1: Forward pass using insert_variables

    root_var, all_vars, code = insert_variables(new_ex)


    # Step 2: Add constraint code:

    local constraint_code

    if constraint == Interval(-∞, ∞)
        constraint_code = :($(root_var) = $(root_var) ∩ _A_)
        push!(all_vars, :_A_)

    else
        constraint_code = :($(root_var) = $(root_var) ∩ $constraint)
    end


    new_code = copy(code)
    push!(new_code.args, constraint_code)


    # Step 3: Backwards pass
    # replace e.g. z = a + b with reverse mode function plusRev(z, a, b)

    for line in reverse(code.args)  # run backwards

        if line.head == :line  # line number node
            continue
        end

        (var, op, args) = @match line begin
            (var_ = op_(args__))  => (var, op, args)
        end

        new_args = []
        push!(new_args, var)
        append!(new_args, args)

        rev_op = rev_ops[op]  # find the reverse operation

        rev_code = :($(rev_op)($(new_args...)))

        return_args = copy(new_args)

        # delete non-symbols in return args:
        for (i, arg) in enumerate(return_args)
            if !(isa(arg, Symbol))
                return_args[i] = :_
            end
        end

        return_tuple = Expr(:tuple, return_args...)  # make tuple out of array
        # or: :($(return_args...),)

        new_line = :($(return_tuple) = $(rev_code))
        push!(new_code.args, new_line)
    end

    sort(all_vars), new_code
end



function make_function(all_vars, code)

    vars = Expr(:tuple, all_vars...)  # make a tuple of the variables

    if all_vars[1] == :_A_
        vars2 = Expr(:tuple, (all_vars[2:end])...)  # miss out _A_
        push!(code.args, :(return $(vars2)))
    else
        push!(code.args, :(return $(vars)))
    end


    function_code = :( $(vars) -> $(code) )

    function_code
end


doc"""`parse_comparison` parses comparisons like `x >= 10`
into the corresponding interval, expressed as `x ∈ [10,∞]  `

Returns the expression and the constraint interval

TODO: Allow something like [3,4]' for the complement of [3,4]'"""

function parse_comparison(ex)
    expr, limits =
    @match ex begin
       ((a_ <= b_) | (a_ < b_))   => (a, (-∞, b))
       ((a_ >= b_) | (a_ > b_))   => (a, (b, ∞))

       a_ == b_                   => (a, (b, b))

       ((a_ <= b_ <= c_)
        | (a_ < b_ < c_))         => (b, (a, c))

       ((a_ >= b_ >= c_)
       | (a_ > b_ > c_))          => (b, (c, a))

       ((a_ ∈ [b_, c_])
       | (a_ in [b_, c_]))        => (a, (b, c))

       _                          => (ex, (-∞, ∞))

   end

   a, b = limits

   expr, @interval(a, b)   # expr ∈ [a,b]

end


type Contractor
    variables::Vector{Symbol}
    constraint_expression::Expr
    contractor::Function
    code::Expr
end

function Contractor(ex::Expr)
    expr, constraint_interval = parse_comparison(ex)

    vars, code = forward_backward(expr, constraint_interval)

    fn = eval(make_function(vars, code))

    Contractor(vars, expr, fn, code)
end

# new call syntax to define a "functor" (object that behaves like a function)
@compat (C::Contractor)(x...) = C.contractor(x...)


function Base.show(io::IO, C::Contractor)
    println(io, "Contractor:")
    println(io, "  - variables: $(C.variables)")
    print(io, "  - constraint: $(C.constraint_expression)")
end

doc"""Usage:
```
C = @contractor(x^2 + y^2 <= 1)
x = y = @interval(0.5, 1.5)
C(x, y)

`@contractor` makes a function that takes as arguments the variables contained in the expression, in lexicographic order
```

TODO: Hygiene for global variables, or pass in parameters
"""

function contractor(ex)
    expr, constraint = parse_comparison(ex)
    @show expr, constraint

    all_vars, code = forward_backward(expr, constraint)
    @show all_vars, code

    make_function(all_vars, code)
end

macro contractor(ex)
    ex = Meta.quot(ex)
    :(Contractor($ex))

end

#= TODO:

=#

#function constraint_propagation(Cs::Vector{Function}, var)


# USAGE
