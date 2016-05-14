# Example of separator:

type Separator
    variables::Vector{Symbol}
    separator::Function
end

function Separator(ex::Expr)
    expr, constraint = parse_comparison(ex)

    C = Contractor(expr)
    variables = C.variables[2:end]

    a = constraint.lo
    b = constraint.hi
    @show C


    f = X -> begin

        inner = C(a..b, X...)  # closure over the function C

        outer1 = C(-∞..a, X...)
        outer2 = C(b..∞, X...)

        # x1, y1 = outer1
        # x2, y2 = outer2
        #
        # x = hull(x1, x2)
        # y = hull(y1, y2)

        outer = [ hull(x1, x2) for (x1,x2) in zip(outer1, outer2) ]

        # outer = (x, y)

        return (inner, (outer...))

    end

    #function_code = :( $(vars) -> $(code) )

    return Separator(variables, f)
    #return (x, y) -> ( C_inner(x, y), C_outer(x, y) )

end

macro separator(ex::Expr)
    #ex = Meta.quot(ex)
    #:(separator($ex))
    Separator(ex)
end

function Base.show(io::IO, S::Separator)
    println(io, "Separator:")
    println(io, "  - variables: $(S.variables)")
    #print(io, "  - constraint: $(S.separator)")
end



@compat (S::Separator)(X) = S.separator(X)


function Base.∩(S1, S2)
    return (x, y) -> begin
        inner1, outer1 = S1(x, y)
        inner2, outer2 = S2(x, y)

        X = map(x -> x[1] ∩ x[2], zip(inner1, inner2))
        Y = map(x -> x[1] ∪ x[2], zip(outer1, outer2))

        return (X, Y)
    end
end

function Base.∪(S1, S2)
    return (x, y) -> begin
        inner1, outer1 = S1(x, y)
        inner2, outer2 = S2(x, y)

        X = map(x -> x[1] ∪ x[2], zip(inner1, inner2))
        Y = map(x -> x[1] ∩ x[2], zip(outer1, outer2))

        return (X, Y)
    end
end



#     S = @separator x^2 + y^2 <= 1
# x = y = 0.5..1.5; X = (x, y)
# S(X)
#
# S2 = @separator x^2 + y^2 ∈ [0.5,2]
