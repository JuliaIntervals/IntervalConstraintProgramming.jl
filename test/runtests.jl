
using ConstraintPropagation
using ValidatedNumerics

using FactCheck

facts("Separator tests") do
    II = -100..100
    X = IntervalBox(II, II)
    S = @constraint x^2 + y^2 <= 1

    inner, outer = S(X)
    @fact inner --> (-1..1, -1..1)
    @fact outer --> (II, II)

end
