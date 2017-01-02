

type Contractor{F<:Function}
    variables::Vector{Symbol}
    constraint_expression::Expr
    code::Expr
    contractor::F  # function
end


doc"""`parse_comparison` parses comparisons like `x >= 10`
into the corresponding interval, expressed as `x ∈ [10,∞]`

Returns the expression and the constraint interval

TODO: Allow something like [3,4]' for the complement of [3,4]
"""

function parse_comparison(ex)
    expr, limits =
    @match ex begin
       ((a_ <= b_) | (a_ < b_) | (a_ ≤ b_))   => (a, (-∞, b))
       ((a_ >= b_) | (a_ > b_) | (a_ ≥ b_))   => (a, (b, ∞))

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


# new call syntax to define a "functor" (object that behaves like a function)
@compat (C::Contractor)(x...) = C.contractor(x...)

@compat (C::Contractor)(X::IntervalBox) = C.contractor(X...)
#show_code(c::Contractor) = c.code


function Base.show(io::IO, C::Contractor)
    println(io, "Contractor:")
    println(io, "  - variables: $(C.variables)")
    print(io, "  - constraint: $(C.constraint_expression)")
end

doc"""Usage:
```
C = @contractor(x^2 + y^2)
A = -∞..1  # the constraint interval
x = y = @interval(0.5, 1.5)
C(A, x, y)

`@contractor` makes a function that takes as arguments the variables contained in the expression, in lexicographic order
```

TODO: Hygiene for global variables, or pass in parameters
"""

macro contractor(ex)
    # println("@contractor; ex=$ex")

    make_contractor(ex)
end




#function Contractor(ex::Expr)
function make_contractor(ex::Expr)
    # println("Entering Contractor(ex) with ex=$ex")
    expr, constraint_interval = parse_comparison(ex)

    if constraint_interval != entireinterval()
        warn("Ignoring constraint; include as first argument")
    end

    top, linear_AST = flatten(expr)

    # @show top, linear_AST

    forward = forward_pass(linear_AST)
    backward = backward_pass(linear_AST)



    # TODO: What about interval box constraints?
    input_arguments = forward.input_arguments
    augmented_input_arguments = [:_A_; forward.input_arguments]

    # @show input_arguments
    # @show augmented_input_arguments

    # add constraint interval as first argument

    input_variables = make_tuple(input_arguments)
    augmented_input_variables = make_tuple(augmented_input_arguments)

    forward_output = make_tuple(forward.output_arguments)

    backward_output = make_tuple(backward.output_arguments)

    # @show forward
    # @show backward
    #
    # @show input_variables
    # @show forward_output
    # @show backward_output

    if isa(top, Symbol)
        # nothing
    elseif length(top) == 1  # single variable
        top = top[]

    else
        # TODO: implement what happens for multiple variables in the constraint
        # using an IntervalBox and intersection of IntervalBoxes
    end

    top_args = make_tuple(top)

    local intersect_code

    if isa(top_args, Symbol)
        intersect_code = :($top_args = $top_args ∩ _A_)  # check type stability
    else
        intersect_code = :($top_args = IntervalBox($top_args) ∩ _A_)  # check type stability
    end


    code =
        #esc(quote
        quote
            $(augmented_input_variables) -> begin
                forward = $(make_function(forward))
                backward = $(make_function(backward))

                $(forward_output) = forward($(forward.input_arguments...))

                $intersect_code

                $(backward_output) = backward($(backward.input_arguments...))

                return $(input_variables)

            end

        end

    #  @show forward
    #  @show backward
    # #
    #  @show code

    return :(Contractor($(augmented_input_arguments),
                        $(Meta.quot(expr)),
                        $(Meta.quot(code)),
                        $(code)
                        ))
end
