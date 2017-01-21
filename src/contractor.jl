
doc"""
`Contractor` represents a `Contractor` from $\mathbb{R}^N$ to $\mathbb{R}^N$.
Nout is the output dimension of the forward part.
"""
immutable Contractor{N, Nout, F1<:Function, F2<:Function}
    variables::Vector{Symbol}  # input variables
    forward::F1
    backward::F2
    forward_code::Expr
    backward_code::Expr
end

function Contractor(variables::Vector{Symbol}, top, forward, backward, forward_code, backward_code)
    N = length(variables)  # input dimension
    Nout = length(top)
    Contractor{N, Nout, typeof(forward), typeof(backward)}(variables, forward, backward, forward_code, backward_code)
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


@compat function (C::Contractor{N,Nout,F1,F2}){N,Nout,F1,F2,T}(A, X::IntervalBox{N,T}) # X::IntervalBox)
    z = IntervalBox( C.forward(IntervalBox(X...)...)... )
    #z = [1:C.num_outputs] = tuple(IntervalBox(z[1:C.num_outputs]...) ∩ A

    # @show z
    constrained = IntervalBox(z[1:Nout]...) ∩ IntervalBox(A...)
    #@show constrained
    #@show z[(C.num_outputs)+1:end]
    return IntervalBox( C.backward( X...,
                                    constrained...,
                                    z[Nout+1:end]...
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

    @show top

    if isa(top, Symbol)
        top = [top]
    end

    :(Contractor($linear_AST.variables,
                    $top,
                    $forward,
                    $backward,
                    $(Meta.quot(forward)),
                    $(Meta.quot(backward))))

end
