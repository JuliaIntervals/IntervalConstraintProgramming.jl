using ModelingToolkit

@testset "BasicContractor" begin
    @variables x y
    C = BasicContractor(x^2 + y^2)

    @test C(-∞..1, IntervalBox(-∞..∞,2)) == IntervalBox(-1..1, -1..1)

    X =IntervalBox(-1..1,2)
    @test C(X) == 0..2

    @test C((1,2)) == 5
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

    C1 = Contractor([x, y, z], x+y)
    @test C1(A,X) == IntervalBox(0.5..0.5, 0.5..0.5, 0.5..1.5)

    C2 = Contractor([x, y, z], y+z)
    @test C2(A,X) == IntervalBox(0.5..1.5, 0.5..0.5, 0.5..0.5)

    vars = @variables x1 x3 x2

    C = Contractor(vars, x1+x2)
    @test C(A, X) == IntervalBox(0.5..0.5, 0.5..1.5, 0.5..0.5)

end

@testset "Contractor is created by function name " begin
  vars = @variables x y
  g(x, y) = x + y
  C = Contractor(vars, g)

  @test C(-Inf..1, IntervalBox(0.5..1.5, 2)) == IntervalBox(0.5..0.5, 2)

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
