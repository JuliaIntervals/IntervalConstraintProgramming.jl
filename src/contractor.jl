
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



@compat function (C::Contractor{N,Nout,F1,F2}){N,Nout,F1,F2,T}(
    A::IntervalBox{Nout,T}, X::IntervalBox{N,T})

    output, intermediate = C.forward(X)
    output_box = IntervalBox(output)
    constrained = output_box ∩ A

    # if constrained is already empty, eliminate call to backward propagation:

    if isempty(constrained)
        return emptyinterval(X)
    end

    return IntervalBox{N,T}(C.backward(X, constrained, intermediate) )

end

# allow 1D contractors to take Interval instead of IntervalBox for simplicty:
@compat (C::Contractor{N,1,F1,F2}){N,F1,F2,T}(A::Interval{T}, X::IntervalBox{N,T}) = C(IntervalBox(A), X)

function make_contractor(ex::Expr)
    println("Entering Contractor(ex) with ex=$ex")
    expr, constraint_interval = parse_comparison(ex)

    if constraint_interval != entireinterval()
        warn("Ignoring constraint; include as first argument")
    end


    top, linear_AST = flatten(expr)

     @show expr
     @show top
     @show linear_AST

    forward_code, backward_code  = forward_backward(linear_AST)

    num_outputs = isa(linear_AST.top, Symbol) ? 1 : length(linear_AST.top)

    # @show top

    if isa(top, Symbol)
        top = [top]
    end

    @show forward_code

    :(Contractor($(linear_AST.variables),
                    $top,
                    $forward_code,
                    $backward_code,
                    $(Meta.quot(forward_code)),
                    $(Meta.quot(backward_code))))

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
    make_contractor(ex)
end
