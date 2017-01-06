

immutable Contractor{F1<:Function, F2<:Function}
    variables::Vector{Symbol}  # input variables
    num_outputs::Int
    forward::F1
    backward::F2
    forward_code::Expr
    backward_code::Expr
end


# function Base.show(io::IO, C::Contractor)
#     println(io, "Contractor:")
#     println(io, "  - variables: $(C.variables)")
#     print(io, "  - constraint: $(C.constraint_expression)")
# end

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
    make_contractor(ex)
end


@compat function (C::Contractor{F1,F2}){F1,F2}(A, X) # X::IntervalBox)
    z = IntervalBox( C.forward(IntervalBox(X...)...)... )
    #z = [1:C.num_outputs] = tuple(IntervalBox(z[1:C.num_outputs]...) ∩ A

    # @show z
    constrained = IntervalBox(z[1:C.num_outputs]...) ∩ IntervalBox(A...)
    #@show constrained
    #@show z[(C.num_outputs)+1:end]
    return IntervalBox( C.backward( X...,
                                    constrained...,
                                    z[(C.num_outputs)+1:end]...
                                  )...
                       )
end

function make_contractor(ex::Expr)
    # println("Entering Contractor(ex) with ex=$ex")
    expr, constraint_interval = parse_comparison(ex)

    if constraint_interval != entireinterval()
        warn("Ignoring constraint; include as first argument")
    end

    top, linear_AST = flatten(expr)

    # @show top, linear_AST

    forward, backward  = forward_backward(linear_AST)

    num_outputs = isa(linear_AST.top, Symbol) ? 1 : length(linear_AST.top)

    :(Contractor($linear_AST.variables,
                    $num_outputs,
                    $forward,
                    $backward,
                    $(Meta.quot(forward)),
                    $(Meta.quot(backward))))

end
