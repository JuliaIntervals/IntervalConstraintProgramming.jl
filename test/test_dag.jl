using IntervalArithmetic, IntervalArithmetic.Symbols
using IntervalConstraintProgramming
using IntervalConstraintProgramming: build_dag, forward!, backward!, propagate!,
    SharedDAG, add_expression!, ConstraintEntry
using Symbolics
using IntervalBoxes
using Test

const IType{T} = Union{Interval{T}, BareInterval{T}}
eq(a::IType, b::IType) = isequal_interval(bareinterval(a), bareinterval(b))
eq(a::IntervalBox, b::IntervalBox) = all(eq.(a, b))
eq(a::Vector, b::Vector) = length(a) == length(b) && all(eq.(a, b))

@testset "SharedDAG construction" begin
    vars = @variables x, y

    dag = SharedDAG(vars)
    @test length(dag.variables) == 2
    @test length(dag.nodes) == 2  # just variable nodes
    @test dag.variables[1].name == :x
    @test dag.variables[2].name == :y

    add_expression!(dag, x^2 + y^2, interval(-Inf, 0.0))
    @test length(dag.constraints) == 1
    @test length(dag.nodes) > 2
end

@testset "SharedDAG node reuse (CSE)" begin
    vars = @variables x, y

    dag = SharedDAG(vars)
    add_expression!(dag, x^2 + y^2 - 1, interval(-Inf, 0.0))
    add_expression!(dag, x^2 - y, interval(-Inf, 0.0))

    pow_nodes = filter(n -> n isa IntervalConstraintProgramming.OperationNode && n.op === (^), dag.nodes)
    @test length(pow_nodes) == 2  # x^2 and y^2, not a duplicate x^2

    @test length(dag.constraints) == 2
end

@testset "SharedDAG n-ary decomposition" begin
    vars = @variables x, y

    dag = build_dag(x + y + 1, vars, interval(0.0))
    ops = filter(n -> n isa IntervalConstraintProgramming.OperationNode, dag.nodes)
    for op in ops
        @test length(op.children) <= 2
    end
end

@testset "Forward propagation" begin
    vars = @variables x, y

    dag = build_dag(x^2 + y^2, vars, interval(-Inf, 1.0))
    X = IntervalBox(interval(0.0, 1.0), interval(0.0, 1.0))
    forward!(dag, X)
    root_range = dag.constraints[1].root.range
    @test inf(root_range) <= 0.0 + 1e-10
    @test sup(root_range) >= 2.0 - 1e-10
end

@testset "Single-expression propagation" begin
    vars = @variables x, y

    ex, constraint = IntervalConstraintProgramming.analyse(x^2 + y^2 <= 1)
    dag = build_dag(ex, vars, constraint)
    X = IntervalBox(interval(-10.0, 10.0), 2)
    result = propagate!(dag, X)
    @test all(inf.(result) .>= -1.0 - 1e-10)
    @test all(sup.(result) .<= 1.0 + 1e-10)
end

@testset "Multi-constraint propagation" begin
    vars = @variables x, y

    dag = SharedDAG(vars)
    add_expression!(dag, x^2 + y^2 - 1, interval(-Inf, 0.0))
    add_expression!(dag, x - y, interval(0.0, Inf))

    X = IntervalBox(interval(-10, 10), 2)
    result = propagate!(dag, X)
    @test all(inf.(result) .>= -1.0 - 1e-10)
    @test all(sup.(result) .<= 1.0 + 1e-10)

    # y ≥ x² narrows y ≥ 0
    dag2 = SharedDAG(vars)
    add_expression!(dag2, x^2 + y^2 - 1, interval(-Inf, 0.0))
    add_expression!(dag2, x^2 - y, interval(-Inf, 0.0))
    result2 = propagate!(dag2, IntervalBox(interval(-10, 10), 2))
    @test inf(result2[2]) >= -1e-10  # y ≥ 0
end

@testset "DAGContractor" begin
    vars = @variables x, y

    C = DAGContractor(x^2 + y^2, vars)
    X = IntervalBox(-Inf..Inf, 2)
    result = C(X, -Inf..1)
    @test eq(result, IntervalBox(-1..1, 2))

    vars3 = @variables x, y, z
    X3 = IntervalBox(interval(0.5, 1.5), 3)
    C1 = DAGContractor(x + y, vars3)
    @test eq(C1(X3, -Inf..1), IntervalBox(interval(0.5, 0.5), interval(0.5, 0.5), interval(0.5, 1.5)))
end

@testset "DAGContractor with shared DAG" begin
    vars = @variables x, y

    dag = SharedDAG(vars)
    C1 = DAGContractor(dag, x^2 + y^2, vars)
    C2 = DAGContractor(dag, x - y, vars)

    @test C1.dag === C2.dag
    @test length(dag.constraints) == 2
end

@testset "DAGSeparator" begin
    vars = @variables x, y

    II = interval(-100, 100)
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

@testset "DAGSeparator with shared DAG" begin
    vars = @variables x, y

    dag = SharedDAG(vars)
    ex1, c1 = IntervalConstraintProgramming.analyse(x^2 + y^2 <= 1)
    ex2, c2 = IntervalConstraintProgramming.analyse(x >= 0)
    S1 = DAGSeparator(dag, ex1, vars, c1)
    S2 = DAGSeparator(dag, ex2, vars, c2)

    @test S1.contractor.dag === S2.contractor.dag
    @test length(dag.constraints) == 2
end

@testset "DAG pave matches original" begin
    vars = @variables x, y

    S_orig = Separator(x^2 + y^2 <= 1, vars)
    S_dag = DAGSeparator(x^2 + y^2 <= 1, vars)

    X = IntervalBox(interval(-3, 3), 2)
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

    X = IntervalBox(interval(-3, 3), 2)
    boundary, inner, outer = S(X)
    @test eq(inner, IntervalBox(0..3, 2))
end

@testset "DAG 3D torus" begin
    vars = @variables x, y, z

    S = DAGSeparator(3 - sqrt(x^2 + y^2)^2 + z^2 <= 1, vars)
    X = IntervalBox(interval(-10, 10), 3)
    inner, boundary = pave(X, S, 1.0)
    @test inner[1] isa IntervalBox{3, Float64, Interval{Float64}}
end
