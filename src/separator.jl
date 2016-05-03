# Example of separator:

C = @contractor x^2+y^2  # no interval given

function separator(ex::Expr)
    expr, constraint = parse_comparison(ex)

    C = eval(contractor(expr))  # no interval given
    @show C

    a, b = constraint.lo, constraint.hi

    C_inner = (x,y) -> C(a..b, x, y)
    C_outer1 = (x,y) -> C(-∞..a, x, y)
    C_outer2 = (x,y) -> C(b..∞, x, y)

    function C_outer(x, y)
        x1, y1 = C_outer1(x, y)
        x2, y2 = C_outer2(x, y)

        x = hull(x1, x2)
        y = hull(y1, y2)

        x, y
    end

    (x, y) -> ( C_inner(x, y), C_outer(x, y) )

end

macro separator(ex::Expr)
    ex = Meta.quot(ex)
    :(separator($ex))
end

S = ConstraintPropagation.separator(:(x^2 + y^2 <= 1))
x = y = 0.5..1.5
S(x,y)
