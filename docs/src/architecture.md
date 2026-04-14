# Architecture: From Symbolic Expressions to Contractors

This document describes the internal pipeline that converts symbolic mathematical expressions into interval contractors and separators for constraint propagation.

## Overview

IntervalConstraintProgramming works in three stages:

1. **Parse**: A symbolic constraint (e.g. `x^2 + y^2 <= 1`) is normalized to the form `f(x,y) in [a, b]`.
2. **Compile**: The expression `f` is decomposed into SSA (single static assignment) form via common subexpression elimination (CSE), then a forward--backward contractor is generated using [ReversePropagation.jl](https://github.com/JuliaIntervals/ReversePropagation.jl).
3. **Evaluate**: The separator applies the contractor to interval boxes, classifying regions as *inner* (definitely feasible), *outer* (definitely infeasible), or *boundary* (unknown).

```
Symbolic expression  (Symbolics.jl)
        |
   separator(ex, vars)
        |
        v
  Normalize: f(x) in constraint
        |
        +---> make_function(f, vars)          --> evaluation function
        +---> Contractor(f, vars)
                  |
                  v
           forward_backward_contractor(f, vars)   [ReversePropagation]
                  |
                  +---> cse_equations(f)           --> SSA assignments
                  +---> constraint intersection
                  +---> rev.() on each assignment  --> backward propagation
                  +---> eval()                     --> compiled Julia closure
                  |
                  v
             Separator(vars, f, constraint, eval_fn, contractor)
```

## Stage 1: Parsing and normalization

The entry point is `separator(ex)` (or equivalently `constraint(ex)`), defined in `src/utils.jl`.

Given a symbolic expression, it:

- **Detects the operator** (`<=`, `>=`, `==`, `&`, `|`, `!`) at the top level.
- **Handles logical connectives** recursively:
  - `A & B` becomes `separator(A)` meet `separator(B)`
  - `A | B` becomes `separator(A)` join `separator(B)`
  - `!A` swaps inner and outer of `separator(A)`
- **Normalizes inequalities** by moving everything to one side:
  - `lhs <= rhs` becomes `lhs - rhs` with constraint `[-Inf, 0]`
  - `lhs >= rhs` becomes `lhs - rhs` with constraint `[0, +Inf]`
  - `lhs == rhs` becomes `lhs - rhs` with constraint `[0, 0]`

The `in` operator is handled symbolically:
```julia
Base.in(x::Num, y::Interval) = (x >= Num(inf(y))) & (x <= Num(sup(y)))
```
so `x^2 + y^2 in interval(0, 1)` decomposes into two inequality constraints combined with `&`.

## Stage 2: Compilation via ReversePropagation

### Common Subexpression Elimination (CSE)

The function `cse_equations(ex)` in ReversePropagation (`src/cse.jl`) recursively decomposes the expression into binary operations, assigning a fresh variable to each subexpression:

```
Input:  3x^2 + 4x^2*y

Output (SSA assignments):
  _a := x * x
  _b := 3 * _a
  _c := _a * y
  _d := 4 * _c
  _e := _b + _d
```

Common subexpressions (like `x * x`) are computed only once.

### Forward--backward contractor (HC4Revise)

The function `forward_backward_code(ex, vars)` in `src/reverse_icp.jl` generates the full contractor:

1. **Forward pass**: The CSE assignments evaluate `f` with interval arithmetic.
2. **Constraint intersection**: The result is intersected with the constraint interval:
   ```
   value := _e
   _e := _e meet constraint
   ```
3. **Backward pass**: Each CSE assignment is reversed using `rev()`, which calls the corresponding reverse function from [IntervalContractors.jl](https://github.com/JuliaIntervals/IntervalContractors.jl) (e.g. `plus_rev`, `mul_rev`, `sin_rev`). These propagate the constraint back through each operation, contracting the input intervals.

The resulting code is compiled into a Julia closure via `eval()`.

### Reverse operations

For each elementary operation, IntervalContractors provides a *reverse* (or *backward*) function:

| Forward         | Reverse         | Effect                                    |
|-----------------|-----------------|-------------------------------------------|
| `z := x + y`    | `plus_rev`      | Contract `x` and `y` given constraint on `z` |
| `z := x * y`    | `mul_rev`       | Contract `x` and `y` given constraint on `z` |
| `z := sin(x)`   | `sin_rev`       | Contract `x` given constraint on `z`      |
| `z := x ^ n`    | `power_rev`     | Contract `x` given constraint on `z`      |

These are registered as symbolic functions so they can appear in generated code.

## Stage 3: Separator evaluation

A `Separator` stores both the compiled evaluation function and the contractor. When called with an `IntervalBox`:

```julia
function (SS::Separator)(X::IntervalBox)
    # 1. Contract: find the boundary region
    boundary = SS.contractor(X)

    # 2. Evaluate at corners to classify inner/outer
    lb_image = SS.f(inf.(X))
    ub_image = SS.f(sup.(X))

    # 3. If a corner satisfies the constraint, extend inner; otherwise extend outer
    inner = boundary
    outer = boundary
    # ... extend with corner evaluations ...

    return (boundary, inner, outer)
end
```

For boxes extending to infinity, a different strategy is used: the contractor is applied once with the constraint and once with its complement, and inner/outer are determined from those two contractions.

### Separator composition

Separators compose via set-theoretic operations defined in `src/set_operations.jl`:

| Operation | Symbol | Inner               | Outer               |
|-----------|--------|----------------------|----------------------|
| Intersect | `S1 meet S2`   | `inner1 meet inner2` | `outer1 join outer2` |
| Union     | `S1 join S2`   | `inner1 join inner2` | `outer1 meet outer2` |
| Complement| `!S`           | swap inner/outer     | swap inner/outer     |

## Paving

The `pave(X, S, epsilon)` function in `src/pave.jl` recursively subdivides the domain box `X`:

1. Apply the separator to get `(boundary, inner, outer)`.
2. Regions proven inner are accumulated.
3. Regions proven outer are discarded.
4. Boundary regions are bisected and re-processed until their diameter falls below `epsilon`.

The result is two collections: `inner` boxes (guaranteed feasible) and `boundary` boxes (undetermined at this tolerance).

## Gradient computation

ReversePropagation also provides `gradient_code(ex, vars)` which generates SSA code for the gradient of `ex` using reverse-mode automatic differentiation (via ChainRules.jl):

1. **Forward pass**: Same CSE decomposition as above.
2. **Initialization**: Set the adjoint of the output to 1.
3. **Adjoint pass**: For each forward assignment in reverse order, compute the adjoint contribution using `rrule` from ChainRules.

The result is a sequence of assignments whose final variables hold the partial derivatives. This SSA code can itself be fed back into the forward--backward machinery to create contractors for derivative constraints.
