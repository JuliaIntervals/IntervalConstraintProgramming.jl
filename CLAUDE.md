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

## ReversePropagation SSAFunction / RuntimeGeneratedFunctions migration (2026-04-20)

### Versions

Bumped `ReversePropagation` compat from `"0.3 - 0.4"` to `"0.8"`. Added a direct dependency on `RuntimeGeneratedFunctions = "0.5"` (transitively available through RP, but worth owning directly since we now call `@RuntimeGeneratedFunction` ourselves). Bumped the package version to `0.16.0`.

### Why

RP 0.5+ reshapes `cse_equations`, `forward_backward_code`, `forward_backward_contractor`, and `gradient_code` around a new `SSAFunction` value: SSA `code`, an `output` variable, and a `variables` NamedTuple carrying extras like `constraint`. It also replaces `eval` with `@RuntimeGeneratedFunction` so a generated function can be built and called within the same dynamic extent (no world-age error) and with a 4–15× faster build time.

### Code changes

**`src/IntervalConstraintProgramming.jl`** — bring in `SSAFunction` and `cse_equations` from RP; call `RuntimeGeneratedFunctions.init(@__MODULE__)` so `@RuntimeGeneratedFunction` works inside this module; export `SSAFunction`.

**`src/utils.jl`** — `make_function` now wraps `build_function(...)` in `@RuntimeGeneratedFunction` instead of `eval`. Same reasons as upstream RP: no world-age hazard, faster build.

**`src/contractor.jl`** — `Contractor` now stores the `SSAFunction` it was built from:
- `Contractor(ex, vars)` calls `cse_equations(ex)` once and forwards to
- `Contractor(ssa::SSAFunction, ex, vars)` which calls `forward_backward_contractor(ssa, vars)` (the SSA-taking method).
- `Separator(ex, vars, constraint::Interval)` runs `cse_equations(ex)` once and shares the SSA between `make_function(ex, vars)` (forward evaluator) and `Contractor(ssa, ex, vars)` (HC4Revise), so each constructor does CSE on `ex` only once rather than twice.

### Known issues

- This change requires ReversePropagation `0.8.0`, which is not registered yet at the time of writing — to develop/test against it, `]dev` the local RP checkout.
