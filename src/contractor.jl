# Own version of gensym:
#const symbol_number = [1]
const symbol_numbers = Dict{Symbol, Int}()

doc"""Return a new, unique symbol like _z10_"""

make_symbol() = make_symbol(:z)

function make_symbol(s::Symbol)

    i = get(symbol_numbers, s, 1)
    symbol_numbers[s] = i + 1

    Symbol("_", s, "_", i, "_")
end

doc"""
`insert_variables` takes a Julia `Expr`ession (i.e. an abstract syntax tree) and
recursively replaces operations like `a+b` by assignments
of the form `_z10_ = a+b`, where `_z10_` is a distinct symbol,
created using `make_symbol` (which is like `gensym`, but more readable).

Returns:

1. generated variable at head (top) of tree, which will contain the result of the whole tree;
2. sorted vector of (external) variables contained in the tree;
3. vector of intermediate variables (both introduced by the user, and generated);
4. code generated.

Usage: `IntervalConstraintProgramming.insert_variables(:(x^2 + y^2))`
"""
function insert_variables(ex)  # numbers are leaves
    ex, Symbol[], Symbol[], quote end
end

function insert_variables(ex::Symbol)  # symbols are leaves
    ex, [ex], Symbol[], quote end
end


function insert_variables(ex::Expr)

    if ex.head == :$   # process constants of form $a
        return :(esc($(ex.args[1]))), Symbol[], Symbol[], quote end

    elseif ex.head == :call
        process_call(ex)

    elseif ex.head == :(=)
        process_assignment(ex)

    elseif ex.head == :block
        process_block(ex)

    elseif ex.head == :tuple
        process_tuple(ex)

    elseif ex.head == :return
        process_return(ex)
    end
end

function process_tuple(ex)
    @show ex, ex.args

    new_code = quote end
    current_args = []  # the arguments in the current expression that will be added
    all_vars = Set{Symbol}()  # all variables contained in the sub-expressions
    top_vars = Symbol[]
    generated_variables = Symbol[]

    top_vars = Symbol[]

    for arg in ex.args
        top, contained_vars, generated, code = insert_variables(arg)

        union!(all_vars, contained_vars)
        append!(new_code.args, code.args)  # add previously-generated code
        append!(generated_variables, generated)

        push!(top_vars, top)
    end

    @show top_vars
    @show new_code
    #exit(1)

    return top_vars, sort(collect(all_vars)), generated_variables, new_code

end

function process_return(ex)
    top, contained_vars, generated, code = insert_variables(ex.args[1])
    append!(code.args, :(return $top))

    top, contained_vars, generated, code
end


function process_block(ex)

    new_code = quote end
    current_args = []  # the arguments in the current expression that will be added
    all_vars = Set{Symbol}()  # all variables contained in the sub-expressions
    generated_variables = Symbol[]

    local top

    for arg in ex.args[1:end]

        isa(arg, LineNumberNode) && continue
        (isa(arg, Expr) && arg.head == :line) && continue

        top, contained_vars, generated, code = insert_variables(arg)

        push!(current_args, top)
        union!(all_vars, contained_vars)
        append!(new_code.args, code.args)  # add previously-generated code
        append!(generated_variables, generated)
    end

    return top, sort(collect(all_vars)), generated_variables, new_code
end


function process_assignment(ex)
    # assumes ex is an assignment
    process_call(ex.args[2], ex.args[1])

end


function process_call(ex, new_var=nothing)
    # new_var is an optional variable name to assign the result of the call to
    # if none is given, then a new, unique variable name is created

    op = ex.args[1]

    if isa(op, Expr) && op.head == :line
         return quote end, Symbol[], Symbol[], quote end
     end

    # rewrite +(a,b,c) as +(a,+(b,c)):
    # TODO: Use @match here!

    if op in (:+, :*) && length(ex.args) > 3
        return insert_variables( :( ($op)($(ex.args[2]), ($op)($(ex.args[3:end]...) )) ))
    end

    new_code = quote end
    current_args = []  # the arguments in the current expression that will be added
    all_vars = Set{Symbol}()  # all variables contained in the sub-expressions
    generated_variables = Symbol[]

    for arg in ex.args[2:end]

        isa(arg, LineNumberNode) && continue

        top, contained_vars, generated, code = insert_variables(arg)

        push!(current_args, top)
        union!(all_vars, contained_vars)
        append!(new_code.args, code.args)  # add previously-generated code
        append!(generated_variables, generated)
    end

    top_level_code = quote end

    #@show op

    if op ∈ keys(rev_ops)  # standard operator
        if new_var == nothing
            new_var = make_symbol()
        end

        push!(generated_variables, new_var)

        top_level_code = :($(new_var) = ($op)($(current_args...)))  # new top-level code

    else  # assume user-defined function

        function_name = :($(op).forward)  # need esc?

        func_args = registered_functions[op]
        @show func_args

        new_generated_vars = Symbol[]
        for i in func_args.generated
            push!(new_generated_vars, make_symbol())
        end

        append!(generated_variables, new_generated_vars)
        new_var = new_generated_vars[end]

        new_generated_vars = Expr(:tuple, new_generated_vars...)



        top_level_code = :($(new_generated_vars) = $(function_name)($(current_args...)))  # new top-level code

    end


    push!(new_code.args, top_level_code)

    return new_var, sort(collect(all_vars)), generated_variables, new_code

end

function constraint(root_var, constraint_interval)
    # if constraint == Interval(-∞, ∞)
    #     constraint_code = :($(root_var) = $(root_var) ∩ _A_)
    #     # push!(all_vars, :_A_)
    #
    # else
        constraint_code = :( $(root_var) = $(root_var) ∩ $(constraint_interval) )
    # end

    return constraint_code


    # new_code = quote end
    # push!(new_code.args, constraint_code)
end


function forward_pass(ex::Expr)
    root, all_vars, generated, code = insert_variables(ex)
    forward_pass(root, all_vars, generated, code)
end

function forward_pass(root, all_vars, generated, code)
    make_function(all_vars, generated, code)
end


function backward_pass(ex::Expr) #, constraint::Interval)
    root, all_vars, generated, code = insert_variables(ex)
    backward_pass(root, all_vars, generated, code)
end


doc"""`backward_pass` replaces e.g. `z = a + b` with
the corresponding reverse-mode function, `(z, a, b) = plusRev(z, a, b)`
"""

function backward_pass(root_var, all_vars, generated, code)

    new_code = quote end

    for line in reverse(code.args)  # run backwards

        line.head == :line  && continue  # ignore line number nodes

        (var, op, args) = @match line begin
            (var_ = op_(args__))  => (var, op, args)
        end

        #@show "hello", op




        if (@capture(op, f_.forward))  # user-defined forward
            rev_op = :($f.backward)
            #println("Hello there")
            @show var, op, args

            return_args = [args...; var.args...]
            rev_code = :($(rev_op)($(return_args...)))

            #return_args =

        else
            return_args = [var, args...]
            rev_op = rev_ops[op]  # find reverse operation

            rev_code = :($(rev_op)($(return_args...)))


            # delete non-symbols in return args:
            for (i, arg) in enumerate(return_args)
                if !(isa(arg, Symbol))
                    return_args[i] = :_
                end
            end

         end



        return_tuple = Expr(:tuple, return_args...)  # make tuple out of array
        # or: :($(return_args...),)

        new_line = :($(return_tuple) = $(rev_code))
        push!(new_code.args, new_line)


    end

    sort!(all_vars)

    make_function(vcat(all_vars, generated), all_vars, new_code)
end

doc"""
`forward_backward` takes in an expression like `x^2 + y^2` and outputs
code for the forward-backward contractor

TODO: Add intersections in forward direction
"""
function forward_backward(ex::Expr, constraint::Interval=entireinterval())

    new_ex = copy(ex)

    # Step 1: Forward pass using insert_variables

    root_var, all_vars, generated, code = insert_variables(new_ex)


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

    # @show code

    function_code = :( $(vars) -> $(code) )

    function_code
end




doc"""`parse_comparison` parses comparisons like `x >= 10`
into the corresponding interval, expressed as `x ∈ [10,∞]`

Returns the expression and the constraint interval

TODO: Allow something like [3,4]' for the complement of [3,4]'"""

function parse_comparison(ex)
    expr, limits =
    @match ex begin
       ((a_ <= b_) | (a_ < b_))   => (a, (-∞, b))
       ((a_ >= b_) | (a_ > b_))   => (a, (b, ∞))

       ((a_ == b_) | (a_ = b_))   => (a, (b, b))

       ((a_ <= b_ <= c_)
        | (a_ < b_ < c_)
        | (a_ <= b_ < c)
        | (a_ < b_ <= c))         => (b, (a, c))

       ((a_ >= b_ >= c_)
       | (a_ > b_ > c_)
       | (a_ >= b_ > c_)
       | (a_ > b_ >= c))          => (b, (c, a))

       ((a_ ∈ [b_, c_])
       | (a_ in [b_, c_])
       | (a_ ∈ b_ .. c_)
       | (a_ in b_ .. c_))        => (a, (b, c))

       _                          => (ex, (-∞, ∞))

   end

   a, b = limits

   return (expr, a..b)   # expr ∈ [a,b]

end


type Contractor
    variables::Vector{Symbol}
    constraint_expression::Expr
    contractor::Function
    code::Expr
end

function Contractor(ex::Expr)
    expr, constraint_interval = parse_comparison(ex)

    top, linear_AST = flatten!(expr)

    @show top, linear_AST

    forward = forward_pass(linear_AST)
    backward = backward_pass(linear_AST)

    input_variables = make_tuple(forward.input_arguments)
    forward_output = make_tuple(forward.output_arguments)

    backward_output = make_tuple(backward.output_arguments)

    code = quote
        $(input_variables) -> begin
            forward = $(make_function(forward))
            backward = $(make_function(backward))

            $(forward_output) = forward($(forward.input_arguments...))

            $(top) = $(top) ∩ $(constraint_interval)

            $(backward_output) = backward($(backward.input_arguments...))

        end
    end

    #@show forward
    #@show backward

    @show code

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


show_code(c::Contractor) = c.code
