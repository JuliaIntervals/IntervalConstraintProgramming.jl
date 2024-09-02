using IntervalArithmetic
using IntervalConstraintProgramming
using Symbolics
using IntervalBoxes

using Test

const IntervalType{T} = Union{Interval{T}, BareInterval{T}}

eq(a::IntervalType, b::IntervalType) = isequal_interval(bareinterval(a), bareinterval(b))

eq(a::IntervalBox, b::IntervalBox) = all(eq.(a, b))



@testset "Contractors" begin
    vars = @variables x, y, z

    C = Contractor(x^2 + y^2, [x, y])
    X = IntervalBox(-Inf..Inf, 2)
    @test eq(C(X, -Inf..1), IntervalBox(-1..1, 2))
    @test eq(C(X), 0..0)

    X = IntervalBox(0.5..1.5, 3)
    A = -Inf..1

    C1 = Contractor(x + y, vars)
    @test eq(C1(A, X), IntervalBox(0.5..0.5, 0.5..0.5, 0.5..1.5))

    C2 = Contractor(y + z, vars)
    @test eq(C2(A, X), IntervalBox(0.5..1.5, 0.5..0.5, 0.5..0.5))

    vars = @variables x1, x3, x2

    C = Contractor(x1 + x2, vars)
    @test eq(C(A, X), IntervalBox(0.5..0.5, 0.5..1.5, 0.5..0.5))

end

@testset "Separators" begin

    vars = @variables x, y

    II = -100..100
    X = IntervalBox(II, 2)
    S = Separator(x^2 + y^2 <= 1, vars)

    @test typeof(S) <: IntervalConstraintProgramming.ConstraintSeparator

    boundary, inner, outer = S(X)
    @test eq(inner, IntervalBox(-1..1, 2))
    @test eq(outer, IntervalBox(II, 2))

    X = IntervalBox(-Inf..Inf, -Inf..Inf)
    boundary, inner, outer = S(X)
    @test eq(inner, IntervalBox(-1..1, 2))
    @test eq(outer, IntervalBox(-Inf..Inf, 2))

end


@testset "pave" begin

    vars = @variables x, y

    S1a = Separator(x > 0, vars)
    S1b = Separator(y > 0, vars)

    S1 = S1a ⊓ S1b
    X = IntervalBox(-3..3, 2)

    boundary, inner, outer = S1(X)
    @test eq(inner, IntervalBox(0..3, 2))

    inner, boundary = pave(X, S1, 0.5)

    @test eq(inner, [IntervalBox(1.5..3, 0..3), IntervalBox(0..1.5, 1.5..3)])
    @test eq(isempty(boundary), false)

    S2 = S1a ⊔ S1b
    paving = pave(S2, IntervalBox(-3..3, -3..3), 0.1)
    @test eq(paving.inner, [IntervalBox(-3..0, 0..3), IntervalBox(0..3, -3..3)])
    @test eq(isempty(paving.boundary), false)


    S3 = @constraint x^2 + y^2 <= 1
    X = IntervalBox(-Inf..Inf, -Inf..Inf)
    paving = pave(S3, X, 1.0, 0.5)

    @test eq(paving.inner, [IntervalBox(Interval(0.0, 0.5), Interval(0.0, 0.8660254037844386)),)
                    IntervalBox(Interval(0.0, 0.5), Interval(-0.8660254037844386, 0.0)),
                    IntervalBox(Interval(-0.5, 0.0), Interval(0.0, 0.8660254037844386)),
                    IntervalBox(Interval(-0.5, 0.0), Interval(-0.8660254037844386, 0.0))]

    @test eq(paving.boundary, [ IntervalBox(Interval(0.5, 1.0), Interval(0.0, 0.8660254037844387)),)
                        IntervalBox(Interval(0.0, 0.5), Interval(0.8660254037844386, 1.0)),
                        IntervalBox(Interval(0.5, 1.0), Interval(-0.8660254037844387, 0.0)),
                        IntervalBox(Interval(0.0, 0.5), Interval(-1.0, -0.8660254037844386)),
                        IntervalBox(Interval(-0.5, 0.0), Interval(0.8660254037844386, 1.0)),
                        IntervalBox(Interval(-1.0, -0.5), Interval(0.0, 0.8660254037844387)),
                        IntervalBox(Interval(-0.5, 0.0), Interval(-1.0, -0.8660254037844386)),
                        IntervalBox(Interval(-1.0, -0.5), Interval(-0.8660254037844387, 0.0))]
end



# @testset "Constants" begin
#     x = y = -Inf..Inf
#     X = IntervalBox(x, y)

#     a = 3
#     S4 = @constraint x^2 + y^2 - $a <= 0
#     paving = pave(S4, X)

#     @test eq(paving.ϵ, 0.01)
#     @test eq(length(paving.inner), 1532)
#     length(paving.boundary) == 1536

# end

@testset "Paving a 3D torus" begin
    S5 = @constraint (3 - sqrt(x^2 + y^2))^2 + z^2 <= 1
    x = y = z = -Inf..Inf
    X = IntervalBox(x, y, z)

    paving = pave(S5, X, 1.)

    @test eq(typeof(paving), IntervalConstraintProgramming.Paving{3, Float64})

end

@testset "Volume" begin
    x = 3..5
    @test eq(Vol(x).bounds, 2)

    V = Vol(IntervalBox(-1..1.5, 2..3.5))
    @test eq(typeof(V), IntervalConstraintProgramming.Vol{2, Float64})
    @test eq(V.bounds, 3.75)

end

@testset "Functions" begin
    @function f(x) = 4x;
    C1 = @contractor f(x);
    A = IntervalBox(0.5..1);
    x = IntervalBox(0..1);

    @test eq(C1(A, x), IntervalBox(0.125..0.25)   # x such that 4x ∈ A=[0.5, 1])


    C2 = @constraint f(x) ∈ [0.5, 0.6]
    X = IntervalBox(0..1)

    paving = pave(C2, X)
    @test eq(length(paving.inner), 2)
    @test eq(length(paving.boundary), 2)


    C3 = @constraint f(f(x)) ∈ [0.4, 0.8]
    @test eq(length(paving.inner), 2)
    @test eq(length(paving.boundary), 2)

end


@testset "Nested functions" begin
    @function f(x) = 2x
    @function g(x) = ( a = f(x); a^2 )
    @function g2(x) = ( a = f(f(x)); a^2 )

    C = @contractor g(x)
    C2 = @contractor g2(x)

    A = IntervalBox(0.5..1)
    x = IntervalBox(0..1)

    @test eq(C(A, x), IntervalBox(sqrt(A[1] / 4)))
    @test eq(C2(A, x), IntervalBox(sqrt(A[1] / 16)))

end

@testset "Iterated functions" begin

    @function f(x) = 2x

    A = IntervalBox(0.5..1)
    x = IntervalBox(0..1)

    @function g3(x) = ( a = (f↑2)(x); a^2 )
    C3 = @contractor g3(x)

    @test eq(C3(A, x), IntervalBox(sqrt(A[1] / 16)))
end
