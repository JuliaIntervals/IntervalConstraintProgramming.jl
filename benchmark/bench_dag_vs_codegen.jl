using IntervalConstraintProgramming
using IntervalArithmetic, IntervalArithmetic.Symbols
using IntervalBoxes
using Symbolics
using BenchmarkTools

@variables x, y, z

println("=" ^ 60)
println("Benchmark: DAG vs code-generation constraint propagation")
println("=" ^ 60)

# --- Problem 1: Unit disk (x² + y² ≤ 1) ---

println("\n--- Problem 1: Unit disk (x² + y² ≤ 1) ---\n")

S_codegen = Separator(x^2 + y^2 <= 1, [x, y])
S_dag = DAGSeparator(x^2 + y^2 <= 1, [x, y])
X = IntervalBox(-3..3, 2)

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

X2 = IntervalBox(-5..5, 2)
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

X3 = IntervalBox(-10..10, 3)
println("pave with ϵ = 1.0:")
print("  codegen: ")
r1 = @btime pave($X3, $S_codegen3, 1.0)
print("  DAG:     ")
r2 = @btime pave($X3, $S_dag3, 1.0)
inner1, bnd1 = r1
inner2, bnd2 = r2
println("  codegen: $(length(inner1)) inner, $(length(bnd1)) boundary")
println("  DAG:     $(length(inner2)) inner, $(length(bnd2)) boundary")
