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

## Suppressing the "NG" flag via `exact=true` (2026-04-20)

### Problem

`IntervalArithmetic` v1 sets a "not guaranteed" (NG) flag on any interval that has ever touched a plain (non-`ExactReal`) `Real`. ICP's generated code is full of those — both the literals from the user's expression (the `1` in `x^2 + y^2 == 1`) and the integer exponents that CSE inserts (the `2` in `x^2`). So even `C.f([3..4, 5..6])` came back as `[33.0, 51.0]_com_NG`.

### Why not on the symbolic side

Wrapping literals in the user-facing symbolic expression (`x^2 + y^2 - exact(1)`) does not survive — `Symbolics` normalises `ExactReal` back to a plain `Int`/`Float` during its own simplification. Any fix has to happen on the generated `Expr`, after `Symbolics.build_function` / `ReversePropagation.forward_backward_expr`.

### Design

Added an `exactify(ex)` helper in `src/utils.jl` that walks an `Expr` and wraps every non-`Bool` `Real` literal with `IntervalArithmetic.exact(...)`. Threaded an `exact::Bool = false` keyword argument through `Contractor`, `Separator`, and `separator`/`constraint`:

- `make_function(ex, vars; exact=false)` — runs `exactify` on the `build_function` output when `exact=true`, before `@RuntimeGeneratedFunction`.
- `Contractor(ssa, ex, vars; exact=false)` — when `exact=true`, delegates to `build_fb_contractor`, which replicates RP's outer wrapper locally so it can `exactify` the body before RGF. When `exact=false`, still forwards to `forward_backward_contractor` unchanged (no overhead in the default path).
- `Separator(...; exact=false)` and `separator(...; exact=false)` — threads the keyword through.

### Usage

```julia
julia> C = constraint(x^2 + y^2 == 1, vars; exact=true);
julia> C.f([3..4, 5..6])
[33.0, 51.0]_com         # no NG
julia> C.contractor((-10..10, -10..10))
[-1.0, 1.0]_trv²         # no NG
```

Default behaviour (`exact=false`) is unchanged.
