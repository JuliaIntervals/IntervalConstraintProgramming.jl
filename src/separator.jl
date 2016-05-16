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

    f = X -> begin

        inner = C(a..b, X...)  # closure over the function C

        outer1 = C(-∞..a, X...)
        outer2 = C(b..∞, X...)

        outer = [ hull(x1, x2) for (x1,x2) in zip(outer1, outer2) ]

        return (inner, (outer...))

    end

    return Separator(variables, f)

end

macro separator(ex::Expr)
    Separator(ex)
end

macro constraint(ex::Expr)
    Separator(ex)
end

function Base.show(io::IO, S::Separator)
    println(io, "Separator:")
    print(io, "  - variables: $(S.variables)")
end


@compat (S::Separator)(X) = S.separator(X)

# TODO: when S1 and S2 have different variables -- amalgamate!
function Base.∩(S1::Separator, S2::Separator)
    f = X -> begin
        inner1, outer1 = S1(X)
        inner2, outer2 = S2(X)

        Y1 = tuple( [x ∩ y for (x,y) in zip(inner1, inner2) ]... )
        Y2 = tuple( [x ∪ y for (x,y) in zip(outer1, outer2) ]... )

        return (Y1, Y2)
    end

    return Separator(S1.variables, f)

end

function Base.∪(S1::Separator, S2::Separator)
    f = X -> begin
        inner1, outer1 = S1(X)
        inner2, outer2 = S2(X)

        Y1 = tuple( [x ∪ y for (x,y) in zip(inner1, inner2) ]... )
        Y2 = tuple( [x ∩ y for (x,y) in zip(outer1, outer2) ]... )

        return (Y1, Y2)
    end

    return Separator(S1.variables, f)

end

import Base.!
function !(S::Separator)
    f = X -> begin
        inner, outer = S(X)
        return (outer, inner)
    end

    return Separator(S.variables, f)
end
