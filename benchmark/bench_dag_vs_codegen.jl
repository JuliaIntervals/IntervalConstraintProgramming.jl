using IntervalConstraintProgramming
using IntervalConstraintProgramming: SharedDAG, add_expression!, propagate!
using IntervalArithmetic, IntervalArithmetic.Symbols
using IntervalBoxes
using Symbolics
using BenchmarkTools

@variables x, y, z

println("=" ^ 60)
println("Benchmark: DAG (persistent) vs code-generation")
println("=" ^ 60)

# --- Problem 1: Unit disk (x² + y² ≤ 1) ---

println("\n--- Problem 1: Unit disk (x² + y² ≤ 1) ---\n")

S_codegen = Separator(x^2 + y^2 <= 1, [x, y])
S_dag = DAGSeparator(x^2 + y^2 <= 1, [x, y])
X = IntervalBox(interval(-3, 3), 2)

println("Single separator call on [-3,3]²:")
print("  codegen: ")
@btime $S_codegen($X)
print("  DAG:     ")
@btime $S_dag($X)

for ϵ in [1.0, 0.1, 0.01]
    println("\npave with ϵ = $ϵ:")
    print("  codegen: ")
    r1 = @btime pave($X, $S_codegen, $ϵ)
    print("  DAG:     ")
    r2 = @btime pave($X, $S_dag, $ϵ)
    inner1, bnd1 = r1
    inner2, bnd2 = r2
    println("  codegen: $(length(inner1)) inner, $(length(bnd1)) boundary")
    println("  DAG:     $(length(inner2)) inner, $(length(bnd2)) boundary")
end

# --- Problem 2: Annulus (1 ≤ x² + y² ≤ 4) ---

println("\n--- Problem 2: Annulus (1 ≤ x² + y² ≤ 4) ---\n")

annulus_expr = x^2 + y^2 ∈ interval(1, 4)
S_codegen2 = separator(annulus_expr, [x, y])
S_dag2 = DAGSeparator(annulus_expr, [x, y])

X2 = IntervalBox(interval(-5, 5), 2)
for ϵ in [1.0, 0.1]
    println("pave with ϵ = $ϵ:")
    print("  codegen: ")
    r1 = @btime pave($X2, $S_codegen2, $ϵ)
    print("  DAG:     ")
    r2 = @btime pave($X2, $S_dag2, $ϵ)
    inner1, bnd1 = r1
    inner2, bnd2 = r2
    println("  codegen: $(length(inner1)) inner, $(length(bnd1)) boundary")
    println("  DAG:     $(length(inner2)) inner, $(length(bnd2)) boundary")
end

# --- Problem 3: 3D constraint ---

println("\n--- Problem 3: 3D (3 - sqrt(x²+y²))² + z² ≤ 1) ---\n")

S_codegen3 = Separator(3 - sqrt(x^2 + y^2)^2 + z^2 <= 1, [x, y, z])
S_dag3 = DAGSeparator(3 - sqrt(x^2 + y^2)^2 + z^2 <= 1, [x, y, z])

X3 = IntervalBox(interval(-10, 10), 3)
println("pave with ϵ = 1.0:")
print("  codegen: ")
r1 = @btime pave($X3, $S_codegen3, 1.0)
print("  DAG:     ")
r2 = @btime pave($X3, $S_dag3, 1.0)
inner1, bnd1 = r1
inner2, bnd2 = r2
println("  codegen: $(length(inner1)) inner, $(length(bnd1)) boundary")
println("  DAG:     $(length(inner2)) inner, $(length(bnd2)) boundary")

# --- Problem 4: Multi-constraint on shared DAG ---

println("\n--- Problem 4: Multi-constraint shared DAG ---")
println("    x²+y² ≤ 1 AND x²-y ≤ 0 (jointly propagated)\n")

dag_shared = SharedDAG([x, y])
add_expression!(dag_shared, x^2 + y^2 - 1, interval(-Inf, 0.0))
add_expression!(dag_shared, x^2 - y, interval(-Inf, 0.0))

dag_sep1 = SharedDAG([x, y])
add_expression!(dag_sep1, x^2 + y^2 - 1, interval(-Inf, 0.0))
dag_sep2 = SharedDAG([x, y])
add_expression!(dag_sep2, x^2 - y, interval(-Inf, 0.0))

X4 = IntervalBox(interval(-10, 10), 2)

println("Single propagation call on [-10,10]²:")
print("  shared DAG (joint):      ")
r_shared = @btime propagate!($dag_shared, $X4)
print("  separate DAGs (seq):     ")
r_sep = @btime begin
    r1 = propagate!($dag_sep1, $X4)
    propagate!($dag_sep2, r1)
end
println("  shared result:  ", r_shared)
println("  separate result: ", r_sep)

println("\nShared DAG nodes: ", length(dag_shared.nodes),
        " vs separate: ", length(dag_sep1.nodes) + length(dag_sep2.nodes))
