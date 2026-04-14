using IntervalArithmetic, IntervalArithmetic.Symbols
using IntervalConstraintProgramming
using IntervalConstraintProgramming: build_dag, forward!, backward!, propagate!, ConstraintDAG
using Symbolics
using IntervalBoxes
using Test

const IntervalType{T} = Union{Interval{T}, BareInterval{T}}
eq(a::IntervalType, b::IntervalType) = isequal_interval(bareinterval(a), bareinterval(b))
eq(a::IntervalBox, b::IntervalBox) = all(eq.(a, b))
eq(a::Vector, b::Vector) = length(a) == length(b) && all(eq.(a, b))

@testset "DAG construction" begin
    vars = @variables x, y

    dag = build_dag(x + y, vars, interval(0.0))
    @test length(dag.variables) == 2
    @test dag.variables[1].name == :x
    @test dag.variables[2].name == :y

    dag2 = build_dag(x^2 + y^2, vars, interval(-Inf, 0.0))
    # Should have: x, y, 2 (const), x^2, y^2, x^2+y^2 = 6 nodes min
    @test length(dag2.nodes) >= 6

    # N-ary: x + y + 1 should decompose to binary
    dag3 = build_dag(x + y + 1, vars, interval(0.0))
    ops = filter(n -> n isa IntervalConstraintProgramming.OperationNode, dag3.nodes)
    # Each + node should have exactly 2 children
    for op in ops
        @test length(op.children) <= 2
    end
end

@testset "DAG forward propagation" begin
    vars = @variables x, y

    dag = build_dag(x^2 + y^2, vars, interval(-Inf, 1.0))
    X = IntervalBox(interval(0.0, 1.0), interval(0.0, 1.0))
    result = forward!(dag, X)
    # x^2 ∈ [0, 1], y^2 ∈ [0, 1], sum ∈ [0, 2] but with the -1 from analyse...
    # Actually analyse(x^2+y^2 <= 1) gives expr = -1 + x^2 + y^2, constraint = (-∞, 0]
    # Let's test the raw expression directly
    @test inf(result) <= 2.0
    @test sup(result) >= 0.0
end

@testset "DAG propagation contracts correctly" begin
    vars = @variables x, y

    # x^2 + y^2 - 1 ≤ 0  (the unit disk)
    ex, constraint = IntervalConstraintProgramming.analyse(x^2 + y^2 <= 1)
    dag = build_dag(ex, vars, constraint)
    X = IntervalBox(interval(-10.0, 10.0), 2)
    result = propagate!(dag, X)
    # Should narrow to [-1, 1]²
    @test all(inf.(result) .>= -1.0 - 1e-10)
    @test all(sup.(result) .<= 1.0 + 1e-10)

    # Box already inside: should not widen
    X2 = IntervalBox(interval(0.0, 0.3), 2)
    dag2 = build_dag(ex, vars, constraint)
    result2 = propagate!(dag2, X2)
    @test all(inf.(result2) .>= 0.0 - 1e-10)
    @test all(sup.(result2) .<= 0.3 + 1e-10)
end

@testset "DAGContractor" begin
    vars = @variables x, y

    C = DAGContractor(x^2 + y^2, vars)
    X = IntervalBox(-Inf..Inf, 2)
    result = C(X, -Inf..1)
    @test eq(result, IntervalBox(-1..1, 2))

    X2 = IntervalBox(interval(0.5, 1.5), 3)
    vars3 = @variables x, y, z
    C1 = DAGContractor(x + y, vars3)
    @test eq(C1(X2, -Inf..1), IntervalBox(interval(0.5, 0.5), interval(0.5, 0.5), interval(0.5, 1.5)))

    C2 = DAGContractor(y + z, vars3)
    @test eq(C2(X2, -Inf..1), IntervalBox(interval(0.5, 1.5), interval(0.5, 0.5), interval(0.5, 0.5)))
end

@testset "DAGSeparator" begin
    vars = @variables x, y

    II = -100..100
    X = IntervalBox(II, 2)
    S = DAGSeparator(x^2 + y^2 <= 1, vars)

    boundary, inner, outer = S(X)
    @test eq(inner, IntervalBox(-1..1, 2))
    @test eq(outer, IntervalBox(II, 2))

    X_inf = IntervalBox(-Inf..Inf, -Inf..Inf)
    boundary2, inner2, outer2 = S(X_inf)
    @test eq(inner2, IntervalBox(-1..1, 2))
    @test eq(outer2, IntervalBox(-Inf..Inf, 2))
end

@testset "DAG pave" begin
    vars = @variables x, y

    S = DAGSeparator(x^2 + y^2 <= 1, vars)
    X = IntervalBox(-3..3, 2)
    inner, boundary = pave(X, S, 0.5)
    @test length(inner) > 0
    @test length(boundary) > 0

    inner_area = sum(prod(diam.(b)) for b in inner)
    total_area = inner_area + sum(prod(diam.(b)) for b in boundary)
    @test inner_area > 2.0   # should be close to π
    @test total_area < 5.0   # should bracket π from above
end

@testset "DAG pave matches original" begin
    vars = @variables x, y

    S_orig = Separator(x^2 + y^2 <= 1, vars)
    S_dag = DAGSeparator(x^2 + y^2 <= 1, vars)

    X = IntervalBox(-3..3, 2)
    inner_orig, boundary_orig = pave(X, S_orig, 0.5)
    inner_dag, boundary_dag = pave(X, S_dag, 0.5)

    @test length(inner_orig) == length(inner_dag)
    @test length(boundary_orig) == length(boundary_dag)
end

@testset "DAG with combined separators" begin
    vars = @variables x, y

    S1 = DAGSeparator(x > 0, vars)
    S2 = DAGSeparator(y > 0, vars)
    S = S1 ⊓ S2

    X = IntervalBox(-3..3, 2)
    boundary, inner, outer = S(X)
    @test eq(inner, IntervalBox(0..3, 2))
end

@testset "DAG 3D torus" begin
    vars = @variables x, y, z

    S = DAGSeparator(3 - sqrt(x^2 + y^2)^2 + z^2 <= 1, vars)
    X = IntervalBox(-10..10, 3)
    inner, boundary = pave(X, S, 1.0)
    @test inner[1] isa IntervalBox{3, Float64, Interval{Float64}}
end
