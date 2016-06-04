
using ConstraintPropagation
using ValidatedNumerics

using FactCheck

facts("Separator tests") do
    II = -100..100
    X = IntervalBox(II, II)
    S = @constraint x^2 + y^2 <= 1

    inner, boundary = S(X)
    @fact inner --> (-1..1, -1..1)
    @fact boundary --> (II, II)


    S1a = @constraint 1x > 0
    S1b = @constraint 1y > 0

    S1 = S1a ∩ S1b
    inner, boundary = set_inversion(S7, IntervalBox(-3..3, -3..3), 0.1)
    @fact inner --> [IntervalBox(1.5..3, 0..3), IntervalBox(0..1.5, 0..3)]

    S2 = S1a ∪ S1b
    inner, boundary = set_inversion(S7, IntervalBox(-3..3, -3..3), 0.1)
    @fact inner --> [IntervalBox(-3..0, 0..3), IntervalBox(0..3, -3..3)]
    
end
