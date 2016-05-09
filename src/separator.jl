# Example of separator:

# type Separator
#     constraint::Expr
#     contractor::Contractor
#     interval::Interval
#     separator::Function
# end

function separator(ex::Expr)
    expr, constraint = parse_comparison(ex)

    #C = eval(contractor(expr))  # no interval given
    #expr = Meta.quot(expr)
    C = Contractor(expr)
    @show C

    a, b = constraint.lo, constraint.hi

#     (x,y) -> begin
#     C_inner = (x,y) -> C(a..b, x, y)
#     C_outer1 = (x,y) -> C(-∞..a, x, y)
#     C_outer2 = (x,y) -> C(b..∞, x, y)
# end
    # C_inner = (x,y) -> C(a..b, x, y)
    # C_outer1 = (x,y) -> C(-∞..a, x, y)
    # C_outer2 = (x,y) -> C(b..∞, x, y)
    #
    # function C_outer(x, y)
    #     x1, y1 = C_outer1(x, y)
    #     x2, y2 = C_outer2(x, y)
    #
    #     x = hull(x1, x2)
    #     y = hull(y1, y2)
    #
    #     x, y
    # end



    return (x, y) -> begin
        inner = C(a..b, x, y)

        outer1 = C(-∞..a, x, y)
        outer2 = C(b..∞, x, y)

        x1, y1 = outer1
        x2, y2 = outer2

        x = hull(x1, x2)
        y = hull(y1, y2)

        outer = (x, y)

        (inner, outer)

    end

    #return (x, y) -> ( C_inner(x, y), C_outer(x, y) )

end

macro separator(ex::Expr)
    ex = Meta.quot(ex)
    :(separator($ex))
end

S = @separator x^2 + y^2 <= 1
x = y = 0.5..1.5
S(x,y)

S2 = @separator x^2 + y^2 ∈ [3,4]
