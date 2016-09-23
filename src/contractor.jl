# Own version of gensym:
#const symbol_number = [1]
const symbol_numbers = Dict{Symbol, Int}()

doc"""Return a new, unique symbol like _z10_"""


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
