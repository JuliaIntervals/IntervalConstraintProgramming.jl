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
