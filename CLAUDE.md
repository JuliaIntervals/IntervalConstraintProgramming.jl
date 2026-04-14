# CLAUDE.md

This file tracks decisions and context discovered while working on this package.
(This instruction itself: always write discoveries and decisions into CLAUDE.md.)

## Dependency Update (2026-04-01)

### Versions updated in Project.toml [compat]

| Package              | Old compat   | New compat | Latest version |
|----------------------|-------------|------------|----------------|
| IntervalArithmetic   | 0.22.12     | 1          | 1.0.4          |
| IntervalBoxes        | 0.2         | 0.3        | 0.3.0          |
| IntervalContractors  | 0.5         | 0.6        | 0.6.0          |
| ReversePropagation   | 0.3         | 0.4        | 0.4.0          |
| StaticArrays         | 1           | 1          | 1.9.18 (unchanged) |
| Symbolics            | 5, 6        | 7          | 7.17.0         |

### Code changes needed for compatibility

**Removed `@register_symbolic x ∈ y::Interval`** from `src/IntervalConstraintProgramming.jl`:
- IntervalArithmetic v1.0 follows IEEE 1788 and deliberately does NOT define `Base.==` or `Base.isequal`/`Base.hash` for `Interval`. Users should use `isequal_interval` etc.
- SymbolicUtils uses `isequal`/`hash` for hash-consing symbolic expressions. Embedding an `Interval` in a symbolic expression (via `@register_symbolic x ∈ y::Interval`) triggers `isequal` → `==` → `InconclusiveBooleanOperation` error.
- **Decision: Do NOT define `Base.isequal`/`Base.hash` for `Interval`** — that would be type piracy contradicting IntervalArithmetic's design. Instead, remove the `∈` registration and avoid putting `Interval` values inside symbolic expressions.

**Replaced `@register_symbolic x ∈ y::Interval`** with decomposition in `src/IntervalConstraintProgramming.jl`:
- New: `Base.in(x::Num, y::Interval) = (x >= Num(inf(y))) & (x <= Num(sup(y)))`
- This decomposes `x ∈ a..b` into `(x >= a) & (x <= b)` at the symbolic level, avoiding Interval values in the symbolic tree entirely.
- Users can still write `x^2 + y^2 ∈ interval(0, 1)` — it just gets decomposed into two comparison constraints combined with `&`.

**Changed `Separator` constructor** in `src/contractor.jl`:
- Old: `Separator(ex, vars, constraint::Interval) = Separator(vars, ex ∈ constraint, constraint, ...)`
- New: `Separator(ex, vars, constraint::Interval) = Separator(vars, ex, constraint, ...)`
- The `ex` field no longer wraps in `∈ constraint` (the constraint is already stored separately in the `constraint` field).

**Updated `show` for `AbstractSeparator`** to display constraint info when available (via `hasproperty` check), since `ex` no longer contains it.

**Fixed pre-existing bug in `separator()` in `src/utils.jl`**:
- The `&` and `|` handlers used `∩`/`∪` (`Base.intersect`/`Base.union`) instead of `⊓`/`⊔` (from IntervalArithmetic.Symbols, defined for separators in `set_operations.jl`).
- This bug was never triggered before because tests didn't exercise the `separator()` path with `&`/`|`. It surfaced now because `∈` decomposes into `(expr >= lo) & (expr <= hi)`.

### Known limitations

- Chained comparisons like `0 <= x^2+y^2 <= 1` don't work (Julia lowers to `&&` which requires `Bool`). Users should use `x^2+y^2 ∈ interval(0, 1)` instead. A `@constraint` macro could fix this — see `future.md`.
- ReversePropagation emits many "Method definition overwritten" warnings with Symbolics v7. Harmless but noisy — see `future.md`.

## DAG-based constraint propagation (2026-04-14)

### Overview

Added an alternative constraint propagation engine based on explicit, persistent, shared DAGs (directed acyclic graphs), inspired by the Schichl & Neumaier approach. Lives in `src/dag/`.

**Key types:**
- `SharedDAG` — persistent DAG accumulating constraints. Multiple expressions share variable nodes and common subexpressions (CSE via `objectid`-keyed cache). Built incrementally with `add_expression!`.
- `DAGContractor` / `DAGSeparator` — drop-in replacements for `Contractor`/`Separator` backed by a SharedDAG. Can share a DAG (`DAGContractor(dag, expr, vars)`) or create their own.
- `ConstraintEntry` — a `(root_node, constraint_interval)` pair stored in the SharedDAG.

**Files:** `src/dag/{nodes,build,propagate,contractor}.jl`, `test/test_dag.jl`, `benchmark/bench_dag_vs_codegen.jl`

### Architecture

The DAG is **persistent**: built once, reused across all `pave` iterations. The same `SharedDAG` can back multiple contractors/separators. When `add_expression!` is called, existing nodes (variables and common subexpressions like `x^2`) are reused rather than duplicated.

Propagation with multiple constraints: `propagate!(dag, X)` does forward evaluation (leaves→root), then backward contraction (root→leaves) for **all** constraints in the DAG. Narrowing from one constraint immediately benefits the others since they share variable nodes.

For separator boundary/complement contraction, `propagate!(dag, X, constraint)` overrides the stored constraint on the first root, allowing the same DAG to be used for boundary (`f(x)=0`), inner (`f(x)∈[a,b]`), and complement contraction without rebuilding.

### Performance (benchmarks, persistent shared DAG)

| Problem | ϵ | Codegen | DAG (persistent) | Ratio |
|---------|---|---------|-----------------|-------|
| Unit disk 2D | single call | 1.2 μs | 6.8 μs | 6x |
| Unit disk 2D | 0.1 | 294 μs | 2.5 ms | 8x |
| Unit disk 2D | 0.01 | 2.5 ms | 20 ms | 8x |
| Annulus 2D | 0.1 | 1.7 ms | 10 ms | 6x |
| 3D torus | 1.0 | 12 ms | 97 ms | 8x |

Multi-constraint shared DAG: 10 nodes shared vs 15 separate (33% reduction). Joint propagation of `x²+y²≤1` and `x²-y≤0` correctly narrows `[-10,10]²` to `[-1,1]×[0,1]`.

### Remaining optimizations

1. **Typed operation enum** instead of `Function` field to eliminate dynamic dispatch
2. **Pre-allocated workspace** for child ranges
3. **Compiled propagation schedule** — flat instruction array for tight-loop execution
