
using ConstraintProgramming
using ValidatedNumerics

using FactCheck


facts("Utilities") do
    @fact ConstraintProgramming.unify_variables([:a, :c], [:c, :b]) -->
        ([:a,:b,:c], [1,3], [3,2], [1,0,2], [0,2,1])
end

facts("Separators") do
    II = -100..100
    X = IntervalBox(II, II)
    S = @constraint x^2 + y^2 <= 1

    inner, boundary = S(X)
    @fact inner --> (-1..1, -1..1)
    @fact boundary --> (II, II)

    II = -∞..∞
    X = IntervalBox(II, II)
    inner, boundary = S(X)
    @fact inner --> (-1..1, -1..1)
    @fact boundary --> (II, II)
end

facts("setinverse") do
    S1a = @constraint x > 0
    S1b = @constraint y > 0

    S1 = S1a ∩ S1b
    inner, boundary = setinverse(S1, IntervalBox(-3..3, -3..3), 0.1)
    @fact inner --> [IntervalBox(1.5..3, 0..3), IntervalBox(0..1.5, 0..3)]
    @fact isempty(boundary) --> true

    S2 = S1a ∪ S1b
    inner, boundary = setinverse(S2, IntervalBox(-3..3, -3..3), 0.1)
    @fact inner --> [IntervalBox(-3..0, 0..3), IntervalBox(0..3, -3..3)]
    @fact isempty(boundary) --> true

end
