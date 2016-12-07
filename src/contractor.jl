# Own version of gensym:
#const symbol_number = [1]
const symbol_numbers = Dict{Symbol, Int}()

doc"""Return a new, unique symbol like _z10_"""


type Contractor{F<:Function}
    variables::Vector{Symbol}
    constraint_expression::Expr
    code::Expr
    contractor::F  # function
end

function Contractor(variables, constraint, code)

    println("Entering Contractor with")
    display(Base.Markdown.parse("""
    - variables: $variables
    - constraint: $constraint
    - code: $code
    """)
    )
    #println("- code: $code")

    code = MacroTools.striplines(code)  # remove line number nodes
    Contractor(variables, constraint, code, eval(code))
end

(C::Contractor{F}){F}(X::IntervalBox) = IntervalBox(C(X...)...)



doc"""`parse_comparison` parses comparisons like `x >= 10`
into the corresponding interval, expressed as `x ∈ [10,∞]`

Returns the expression and the constraint interval

TODO: Allow something like [3,4]' for the complement of [3,4]'"""

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

#show_code(c::Contractor) = c.code


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

macro contractor(ex)
    ex = Meta.quot(ex)
    :(Contractor($ex))
end




#function Contractor(ex::Expr)
function make_contractor(ex::Expr)
    println("Entering Contractor(ex) with ex=$ex")
    expr, constraint_interval = parse_comparison(ex)

    top, linear_AST = flatten!(expr)

    @show top, linear_AST

    forward = forward_pass(linear_AST)
    backward = backward_pass(linear_AST)

    input_variables = make_tuple(forward.input_arguments)
    forward_output = make_tuple(forward.output_arguments)

    backward_output = make_tuple(backward.output_arguments)

    @show forward
    @show backward

    @show input_variables
    @show forward_output
    @show backward_output

    if length(top) == 1  # single variable
        top = top[]

    else
        # TODO: implement what happens for multiple variables in the constraint
        # using an IntervalBox and intersection of IntervalBoxes
    end

    code = quote
        $(input_variables) -> begin
            forward = $(make_function(forward))
            backward = $(make_function(backward))

            $(forward_output) = forward($(forward.input_arguments...))

            $(top) = $(top) ∩ $(constraint_interval)

            $(backward_output) = backward($(backward.input_arguments...))

            return $(input_variables)

        end
    end

    #@show forward
    #@show backward

    #@show code


    #fn = eval(make_function(input_variables, code)

    #Contractor(forward.input_arguments, expr, code)

    return forward.input_arguments, expr, code
end



# type Contractor{F}
#     variables::Vector{Symbol}
#     constraint_expression::Expr
#     code::Expr
#     contractor::F  # function
# end
