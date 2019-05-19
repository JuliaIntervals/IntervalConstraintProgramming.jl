
"""
`Contractor` represents a `Contractor` from ``\\mathbb{R}^N`` to ``\\mathbb{R}^N``.
Nout is the output dimension of the forward part.
"""
abstract type AbstractContractor end

struct Contractor{N, Nout, F1<:Function, F2<:Function, ex<:Union{Operation,Expr}} <:AbstractContractor
    variables::Vector{Symbol}  # input variables
    parameters::Vector{Symbol}
    forward::GeneratedFunction{F1}
    backward::GeneratedFunction{F2}
    expression::ex
end

struct BasicContractor{F1<:Function, F2<:Function} <:AbstractContractor
    forward::F1
    backward::F2
end

function Contractor(variables::Vector{Symbol}, parameters::Vector{Symbol}, top, forward, backward, expression)

    # @show variables
    # @show top

    N = length(variables)  # input dimension

    local Nout  # number of outputs

    if isa(top, Symbol)
        Nout = 1

    elseif isa(top, Expr) && top.head == :tuple
        Nout = length(top.args)

    else
        Nout = length(top)
    end

    Contractor{N, Nout, typeof(forward.f), typeof(backward.f), typeof(expression)}(variables, parameters, forward, backward, expression)
end

function Base.show(io::IO, C::Contractor{N,Nout,F1,F2,ex}) where {N,Nout,F1,F2,ex}
    println(io, "Contractor in $(N) dimensions:")
    println(io, "  - forward pass contracts to $(Nout) dimensions")
    println(io, "  - variables: $(C.variables)")
    if !isempty(C.parameters) println(io, "  - parameters: $(C.parameters)") end
    print(io, "  - expression: $(C.expression)")
end

    (C::Contractor)(X) = C.forward(X)[1]
    (C::BasicContractor)(X) = C.forward(X)[1]

function contract(C::AbstractContractor, A::IntervalBox{Nout,T}, X::IntervalBox{N,T}, parameters)where {N,Nout,T}

    for p in parameters
       X = ×(X, p..p)
    end
    output, intermediate = C.forward(X)

    # @show output
    # @show intermediate

    output_box = IntervalBox(output)
    constrained = output_box ∩ A

    # if constrained is already empty, eliminate call to backward propagation:

    if isempty(constrained)
        return emptyinterval(X)
    end

    # @show X
    # @show constrained
    # @show intermediate
    # @show C.backward(X, constrained, intermediate)
    return IntervalBox{N,T}(C.backward(X, constrained, intermediate)[1:N])

end

""" @parameters a b
    C = Contractor(a*x^2 + b*y^2)
    C(-Inf..1, IntervalBox(-1..1,2), 1, 2) = [-1, 1] × [-0.707107, 0.707107]  #parameter's a, b are set to 1,2
"""

function (C::Contractor)(A::IntervalBox{Nout,T}, X::IntervalBox{N,T}, parameters...)where {N,Nout,T}
    return contract(C, A, X, parameters)
end

# allow 1D contractors to take Interval instead of IntervalBox for simplicty:
(C::Contractor)(A::Interval{T}, X::IntervalBox{N,T}, parameters...) where {N,T} = contract(C,IntervalBox(A), X, parameters)


function (C::BasicContractor)(A::IntervalBox{Nout,T}, X::IntervalBox{N,T}, parameters...)where {N,Nout,T}
    return contract(C, A, X)
end

# allow 1D contractors to take Interval instead of IntervalBox for simplicty:
(C::BasicContractor)(A::Interval{T}, X::IntervalBox{N,T}, parameters...) where {N,Nout,T} = contract(C,IntervalBox(A), X, parameters)

""" Contractor can also be construct without the use of macros
 vars = @variables x y z
 C = Contractor(x + y , vars)
 C(-Inf..1, IntervalBox(0.5..1.5,3))
 """

function Contractor(variables, expr::Operation)

    var = [i.op.name for i in variables]
    top, linear_AST = flatten(expr, var)


    forward_code, backward_code  = forward_backward(linear_AST)


    # @show top

    if isa(top, Symbol)
        top = [top]
    end

    forward = eval(forward_code)
    backward = eval(backward_code)

    Contractor(linear_AST.variables, linear_AST.parameters,
                    top,
                    GeneratedFunction(forward, forward_code),
                    GeneratedFunction(backward, backward_code),
                    expr)

end


function BasicContractor(variables, expr::Operation)

    var = [i.op.name for i in variables]
    top, linear_AST = flatten(expr, var)

    forward_code, backward_code  = forward_backward(linear_AST)

    forward = eval(forward_code)
    backward = eval(backward_code)

    BasicContractor{typeof(forward), typeof(backward)}(forward, backward)
end

function Base.show(io::IO, C::BasicContractor{F1,F2}) where {F1,F2}
    println(io, " Basic version of Contractor")
end

BasicContractor(expr::Operation) = BasicContractor([], expr::Operation)

BasicContractor(vars::Union{Vector{Operation}, Tuple{Vararg{Operation,N}}}, g::Function) where N = BasicContractor(vars, g(vars...)) #Contractor can be constructed by function name only

BasicContractor(vars, f::Function) = BasicContractor([Variable(Symbol(i))() for i in vars], f([Variable(Symbol(i))() for i in vars]...))#if vars is not vector of Operation


Contractor(expr::Operation) = Contractor([], expr::Operation)

Contractor(vars::Union{Vector{Operation}, Tuple{Vararg{Operation,N}}}, para::Union{Vector{Operation}, Tuple{Vararg{Operation,N}}}, g::Function) where N = Contractor(vars, g(vars..., para...)) #Contractor can be constructed by function name onlyContractor(vars::Union{Vector{Operation}, Tuple{Vararg{Operation,N}}}, g::Function) where N = Contractor(vars, g(vars...)) #Contractor can be constructed by function name only

Contractor(vars, f::Function) = Contractor([Variable(Symbol(i))() for i in vars], f([Variable(Symbol(i))() for i in vars]...))#if vars is not vector of Operation

function make_contractor(expr::Expr, var = [])
    # println("Entering Contractor(ex) with ex=$ex")
    # expr, constraint_interval = parse_comparison(ex)

    # if constraint_interval != entireinterval()
    #     warn("Ignoring constraint; include as first argument")
    # end


    top, linear_AST = flatten(expr, var)

    #  @show expr
    #  @show top
    #  @show linear_AST

    forward_code, backward_code  = forward_backward(linear_AST)
    # @show top

    if isa(top, Symbol)
        top = [top]

    elseif isa(top, Expr) && top.head == :tuple
        top = top.args

    end
    # @show forward_code
    # @show backward_code

    :(Contractor($(linear_AST.variables),$(linear_AST.parameters),
                    $top,
                    GeneratedFunction($forward_code, $(Meta.quot(forward_code))),
                    GeneratedFunction($backward_code, $(Meta.quot(backward_code))),
                    $(Meta.quot(expr))))

end



"""Usage:
```
C = @contractor(x^2 + y^2)
A = -∞..1  # the constraint interval
x = y = @interval(0.5, 1.5)
C(A, x, y)

`@contractor` makes a function that takes as arguments the variables contained in the expression, in lexicographic order
```

TODO: Hygiene for global variables, or pass in parameters
"""
macro contractor(ex, variables=[])
    isa(variables, Array) ? var = [] : var = variables.args
    make_contractor(ex, var)
end
