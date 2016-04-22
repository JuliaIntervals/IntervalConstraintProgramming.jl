
using ConstraintPropagation
using ValidatedNumerics

include("../src/contractor.jl")


using FactCheck

facts("insert_variables") do

    @fact insert_variables(:x) --> (:x, [:x], quote end)

    top_var, all_vars, ex = insert_variables(:(x+y))
    want = quote z1 = x + y end
    deleteat!(want.args, 1)  # remove LineNumber node

    @fact top_var --> :z1
    @fact all_vars --> [:x, :y]
    @fact ex --> want

end

C1 = @contractor(x^2 + y^2 <= 1)
C2 = @contractor(x^2 + y^2 - 1)
C3 = @contractor(x^2 + y^2 == 1)

x = y = @interval(0.5, 1.5)

facts("Circle contractor") do
    @fact C1(x,y) --> (Interval(0.5, 0.8660254037844387), Interval(0.5, 0.8660254037844387))
    @fact C2(x,y) --> (Interval(0.5, 0.8660254037844387), Interval(0.5, 0.8660254037844387))
    @fact C3(x,y) --> (Interval(0.5, 0.8660254037844387), Interval(0.5, 0.8660254037844387))
end

C4 = @contractor(y^2 + (0.5x)^2 <= 1)
facts("Ellipse contractor") do
    x = 1..3
    y = 0.5..1.5

    @fact C4(x,y) --> (Interval(1.0, 1.7320508075688774), Interval(0.5, 0.8660254037844387))
    @fact C4(y,x) --> (∅, ∅)
end

facts("Reverse square") do
    x = y = entireinterval()
    C = @contractor x^2 + y^2 <= 1
    @fact C(x,y) --> (Interval(-1.0, 1.0), Interval(-1.0, 1.0))
end

facts("Internal") do

    vars, code = ConstraintPropagation.forward_backward(:(x <= 1))
    @fact length(vars) --> 1

    vars, code = ConstraintPropagation.forward_backward(:(x+y <= 1))
    @fact length(vars) --> 2

    vars, code = ConstraintPropagation.forward_backward(:(x^2 + x <= 1))
    @fact length(vars) --> 1
end
