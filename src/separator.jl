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

function Base.show(io::IO, S::Separator)
    println(io, "Separator:")
    print(io, "  - variables: $(S.variables)")
end


import Base.setdiff
doc"""
    setdiff(x::Interval, y::Interval)

Calculate the set difference `x \ y`, i.e. the set of values
inside `x` but not inside `y`.
"""
function setdiff(x::Interval, y::Interval)
    intersection = x ∩ y

    isempty(intersection) && return x
    intersection == x && return emptyinterval(x)

    x.lo == intersection.lo && return Interval(intersection.hi, x.hi)
    x.hi == intersection.hi && return Interval(x.lo, intersection.lo)

    return x   # intersection is inside x; the hull of the setdiff is the whole interval

end

function setdiff(X::IntervalBox, Y::IntervalBox)
    IntervalBox( [setdiff(x,y) for (x,y) in zip(X, Y)] )
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



#     S = @separator x^2 + y^2 <= 1
# x = y = 0.5..1.5; X = (x, y)
# S(X)
#
# S2 = @separator x^2 + y^2 ∈ [0.5,2]
