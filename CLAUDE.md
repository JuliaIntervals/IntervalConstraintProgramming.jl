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

Added an alternative constraint propagation engine based on explicit DAGs (directed acyclic graphs), inspired by the Schichl & Neumaier approach. Lives in `src/dag/` alongside the existing code-generation approach.

**New files:**
- `src/dag/nodes.jl` — `AbstractNode`, `VariableNode`, `ConstantNode`, `OperationNode`, `ConstraintDAG`
- `src/dag/build.jl` — `build_dag()`: walks Symbolics expression tree, builds DAG with CSE via `objectid`-keyed cache. Decomposes n-ary `+`/`*` into left-associated binary chains.
- `src/dag/propagate.jl` — `forward!`, `backward!`, `propagate!` (iterative HC4Revise)
- `src/dag/contractor.jl` — `DAGContractor`, `DAGSeparator` types
- `test/test_dag.jl` — 27 tests (construction, propagation, pave, comparison with original)
- `benchmark/bench_dag_vs_codegen.jl` — head-to-head benchmarks

**New exports:** `DAGContractor`, `DAGSeparator`, `ConstraintDAG`

### Architecture decisions

**DAG rebuilt per contractor call.** The `DAGContractor` rebuilds the DAG each time it's called with a (possibly different) constraint interval. This is correct but slower than caching. The `Separator` protocol requires contracting with `f(x) = 0` (boundary) by default, plus `f(x) ∈ [a,b]` and complement for infinite boxes — so the same expression needs different constraints. A future optimization would cache DAGs per constraint value.

**Mutable node ranges.** Each node stores a mutable `range::Interval` that is updated in-place during propagation. This avoids allocating new interval containers per pass. The trade-off is that the DAG is not thread-safe.

**Reverse contractor dispatch.** Uses explicit `_contract_binary!`/`_contract_unary!` methods dispatching on `typeof(op)` (e.g., `::typeof(+)`, `::typeof(sin)`). Unary ops are generated via `@eval` loop over the IntervalContractors reverse functions. Falls back with a warning for unknown ops.

**N-ary decomposition.** Symbolics.jl represents `x + y + 1` as `+(x, y, 1)` with 3 arguments. The DAG builder decomposes these into left-associated binary chains: `(x + y) + 1`. This is necessary because `plus_rev` and `mul_rev` are binary.

### Performance (benchmarks)

The DAG approach produces **identical results** (same box counts) but is ~10x slower due to:
1. DAG reconstruction per call (no caching)
2. Dynamic dispatch on `node.op` for each forward/backward step
3. Allocation of child-range vectors in `_eval_forward`

| Problem | ϵ | Codegen | DAG | Ratio |
|---------|---|---------|-----|-------|
| Unit disk 2D | 0.1 | 287 μs | 3.2 ms | 11x |
| Unit disk 2D | 0.01 | 2.3 ms | 27 ms | 12x |
| Annulus 2D | 0.1 | 1.6 ms | 14 ms | 9x |
| 3D torus | 1.0 | 12 ms | 120 ms | 10x |

### Potential optimizations (not yet implemented)

1. **Cache DAGs** by constraint value in the separator (avoid rebuilding each call)
2. **Typed operation enum** instead of `Function` field to eliminate dynamic dispatch
3. **Pre-allocated workspace** for child ranges (avoid per-node allocation)
4. **Compiled propagation schedule** — a flat array of `(op_code, input_indices, output_index)` instructions that a tight loop can execute without dynamic dispatch, similar to what the codegen approach produces but without `eval()`
5. **Multi-constraint propagation** — multiple constraints sharing variable nodes in a single DAG, so narrowing from one constraint immediately benefits others (the main theoretical advantage of the Schichl-Neumaier approach over independent contractors)

### Findings during implementation

**Separator boundary semantics.** The existing `Separator` calls its contractor with `constraint = interval(0.0)` (contracting onto the boundary `f(x) = 0`), not with the full constraint interval. This is how it distinguishes inner from boundary from outer. Initial DAG implementation incorrectly contracted with the full constraint, producing no inner boxes. Fixed by making `DAGContractor` accept the constraint as a call-time argument (defaulting to `interval(0.0)`).

**Symbolics literal representation.** Numbers in Symbolics expression trees (e.g., the `2` in `x^2`, the `3` in `3*x`) are wrapped as `BasicSymbolic{SymReal}` objects, not Julia `Number`s. They satisfy `!issym && !iscall` and can be unwrapped via `Symbolics.value()` to get the underlying `Int64`/`Float64`. Variable names are extracted via `Symbolics.nameof()`.

**`+` and `*` parse issue.** Writing `op === + || op === *` causes a Julia parse error because `||` tries to parse `*` as a boolean expression. Must parenthesize: `op === (+) || op === (*)`.
