using IntervalArithmetic
using IntervalConstraintProgramming
using ModelingToolkit
using DynamicPolynomials

using Test

@testset "Utilities" begin
    @test IntervalConstraintProgramming.unify_variables([:a, :c], [:c, :b]) == ([:a,:b,:c], [1,3], [3,2], [1,0,2], [0,2,1])
end

@testset "Contractor" begin
    x = y = -∞..∞
    X = IntervalBox(x, y)

    C = @contractor x^2 + y^2

    @test C(-∞..1, X) == IntervalBox(-1..1, -1..1)

    X =IntervalBox(-1..1,2)
    @test C(X) == 0..2

end

@testset "Contractor without using macro" begin
    @variables x y
    C = Contractor(x^2 + y^2)
    @test  C(-∞..1, IntervalBox(-∞..∞, 2)) == IntervalBox(-1..1, -1..1)

end

@testset "Contractor (with macros and without macros) specifying variables explicitly" begin
    X =IntervalBox(0.5..1.5,3)
    A=-Inf..1

    C1 = @contractor(x+y, [x,y,z])
    @test C1(A,X) == IntervalBox(0.5..0.5, 0.5..0.5, 0.5..1.5)

    C2 = @contractor(y+z, [x,y,z])
    @test C2(A,X) == IntervalBox(0.5..1.5, 0.5..0.5, 0.5..0.5)

    vars = @variables x y z

    C1 = Contractor(vars, x+y)
    @test C1(A,X) == IntervalBox(0.5..0.5, 0.5..0.5, 0.5..1.5)

    C2 = Contractor(vars, y+z)
    @test C2(A,X) == IntervalBox(0.5..1.5, 0.5..0.5, 0.5..0.5)

    C1 = Contractor([:x,:y,:z], x+y)
    @test C1(A,X) == IntervalBox(0.5..0.5, 0.5..0.5, 0.5..1.5)

    C2 = Contractor([:x,:y,:z], y+z)
    @test C2(A,X) == IntervalBox(0.5..1.5, 0.5..0.5, 0.5..0.5)

end

@testset "Contractor is created by function name " begin
  vars = @variables x y
  g(x, y) = x + y
  C = Contractor(vars, g)

  @test C(-Inf..1, IntervalBox(0.5..1.5, 2)) == IntervalBox(0.5..0.5, 2)

end

@testset "Contractors for polynamial functions" begin
    pvars = @polyvar x y
    p(x,y) = x + y
    C = Contractor(pvars, p)
    @test C(-Inf..1, IntervalBox(0.5..1.5, 2)) == IntervalBox(0.5..0.5, 2)
end

@testset "Separators" begin
    II = -100..100
    X = IntervalBox(II, II)
    S = @constraint x^2 + y^2 <= 1

    @test typeof(S) <: IntervalConstraintProgramming.ConstraintSeparator

    inner, outer = S(X)
    @test inner == IntervalBox(-1..1, -1..1)
    @test outer == IntervalBox(II, II)

    X = IntervalBox(-∞..∞, -∞..∞)
    inner, outer = S(X)
    @test inner == IntervalBox(-1..1, -1..1)
    @test outer == IntervalBox(-∞..∞, -∞..∞)

end

@testset "Separators without using macros" begin
    II = -100..100
    X = IntervalBox(II, II)
    vars = @variables x y

    S = Separator(vars, x^2 + y^2 < 1)

    inner, outer = S(X)
    @test inner == IntervalBox(-1..1, -1..1)
    @test outer == IntervalBox(II, II)

    X = IntervalBox(-∞..∞, -∞..∞)
    inner, outer = S(X)
    @test inner == IntervalBox(-1..1, -1..1)
    @test outer == IntervalBox(-∞..∞, -∞..∞)

end

@testset "Separator is created by function name " begin
  vars = @variables x y
  g(x, y) = x + y < 1
  S = Separator(vars, g)

  @test S(IntervalBox(0.5..1.5, 2)) == (IntervalBox(0.5..0.5, 2), IntervalBox(0.5..1.5, 2))

end

@testset "Seperators for polynomial functions" begin
  pvars = @polyvar x y
  p(x,y) = x + y == 1
  S = Separator(pvars, p)

  @test S(IntervalBox(0.5..1.5, 2)) == (IntervalBox(0.5..0.5, 2), IntervalBox(0.5..1.5, 2))

end
@testset "pave" begin
    S1a = @constraint(x > 0 , [x, y])
    S1b = @constraint(y > 0 , [x, y])

    S1 = S1a ∩ S1b
    paving = pave(S1, IntervalBox(-3..3, -3..3), 2.0, 0.5)

    @test paving.inner == [IntervalBox(1.5..3, 0..3), IntervalBox(0..1.5, 1.5..3)]
    @test isempty(paving.boundary) == false

    S2 = S1a ∪ S1b
    paving = pave(S2, IntervalBox(-3..3, -3..3), 0.1)
    @test paving.inner == [IntervalBox(-3..0, 0..3), IntervalBox(0..3, -3..3)]
    @test isempty(paving.boundary) == false


    S3 = @constraint x^2 + y^2 <= 1
    X = IntervalBox(-∞..∞, -∞..∞)
    paving = pave(S3, X, 1.0, 0.5)

    @test paving.inner == [IntervalBox(Interval(0.0, 0.5), Interval(0.0, 0.8660254037844386)),
                    IntervalBox(Interval(0.0, 0.5), Interval(-0.8660254037844386, 0.0)),
                    IntervalBox(Interval(-0.5, 0.0), Interval(0.0, 0.8660254037844386)),
                    IntervalBox(Interval(-0.5, 0.0), Interval(-0.8660254037844386, 0.0))]

    @test paving.boundary == [ IntervalBox(Interval(0.5, 1.0), Interval(0.0, 0.8660254037844387)),
                        IntervalBox(Interval(0.0, 0.5), Interval(0.8660254037844386, 1.0)),
                        IntervalBox(Interval(0.5, 1.0), Interval(-0.8660254037844387, 0.0)),
                        IntervalBox(Interval(0.0, 0.5), Interval(-1.0, -0.8660254037844386)),
                        IntervalBox(Interval(-0.5, 0.0), Interval(0.8660254037844386, 1.0)),
                        IntervalBox(Interval(-1.0, -0.5), Interval(0.0, 0.8660254037844387)),
                        IntervalBox(Interval(-0.5, 0.0), Interval(-1.0, -0.8660254037844386)),
                        IntervalBox(Interval(-1.0, -0.5), Interval(-0.8660254037844387, 0.0))]
end



@testset "Constants" begin
    x = y = -∞..∞
    X = IntervalBox(x, y)

    a = 3
    S4 = @constraint x^2 + y^2 - $a <= 0
    paving = pave(S4, X)

    @test paving.ϵ == 0.01
    @test length(paving.inner) == 1532
    length(paving.boundary) == 1536

end

@testset "Paving a 3D torus" begin
    S5 = @constraint (3 - sqrt(x^2 + y^2))^2 + z^2 <= 1
    x = y = z = -∞..∞
    X = IntervalBox(x, y, z)

    paving = pave(S5, X, 1.)

    @test typeof(paving) == IntervalConstraintProgramming.Paving{3, Float64}

end

@testset "Volume" begin
    x = 3..5
    @test Vol(x).bounds == 2

    V = Vol(IntervalBox(-1..1.5, 2..3.5))
    @test typeof(V) == IntervalConstraintProgramming.Vol{2, Float64}
    @test V.bounds == 3.75

end

@testset "Functions" begin
    @function f(x) = 4x;
    C1 = @contractor f(x);
    A = IntervalBox(0.5..1);
    x = IntervalBox(0..1);

    @test C1(A, x) == IntervalBox(0.125..0.25)   # x such that 4x ∈ A=[0.5, 1]


    C2 = @constraint f(x) ∈ [0.5, 0.6]
    X = IntervalBox(0..1)

    paving = pave(C2, X)
    @test length(paving.inner) == 2
    @test length(paving.boundary) == 2


    C3 = @constraint f(f(x)) ∈ [0.4, 0.8]
    @test length(paving.inner) == 2
    @test length(paving.boundary) == 2

end


@testset "Nested functions" begin
    @function f(x) = 2x
    @function g(x) = ( a = f(x); a^2 )
    @function g2(x) = ( a = f(f(x)); a^2 )

    C = @contractor g(x)
    C2 = @contractor g2(x)

    A = IntervalBox(0.5..1)
    x = IntervalBox(0..1)

    @test C(A, x) == IntervalBox(sqrt(A[1] / 4))
    @test C2(A, x) == IntervalBox(sqrt(A[1] / 16))

end

@testset "Iterated functions" begin

    @function f(x) = 2x

    A = IntervalBox(0.5..1)
    x = IntervalBox(0..1)

    @function g3(x) = ( a = (f↑2)(x); a^2 )
    C3 = @contractor g3(x)

    @test C3(A, x) == IntervalBox(sqrt(A[1] / 16))
end
