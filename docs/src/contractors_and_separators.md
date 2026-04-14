# Contractors and Separators

This page explains the key concepts behind IntervalConstraintProgramming.jl: **contractors** and **separators**. These are the tools that allow us to rigorously determine which regions of space satisfy a given set of constraints.

## Interval boxes

An **interval box** (or simply "box") is a Cartesian product of intervals, representing a rectangular region in $n$-dimensional space. For example, in 2D:

$$X = [1, 3] \times [0, 2]$$

is the rectangle with $x \in [1, 3]$ and $y \in [0, 2]$.

In Julia, we write:

```julia
using IntervalArithmetic, IntervalBoxes
X = IntervalBox(interval(1, 3), interval(0, 2))
```

## Contractors

A **contractor** $C$ is an operator that takes an interval box $X$ and returns a smaller (or equal) box $C(X) \subseteq X$. The key property is:

> **Contractance**: $C(X) \subseteq X$ for all boxes $X$.

Given an expression like $x^2 + y^2$ and a constraint interval like $[0, 1]$, a contractor shrinks the input box to eliminate regions that are *guaranteed* not to satisfy the constraint $x^2 + y^2 \in [0, 1]$.

### How contraction works: forward--backward propagation

IntervalConstraintProgramming uses a **forward--backward contractor**, also known as constraint propagation:

1. **Forward pass**: Evaluate the expression using interval arithmetic. Each intermediate result gets an interval that encloses all possible values.

2. **Constraint intersection**: Intersect the result with the constraint interval. If the expression evaluates to $[{-0.5}, 1.5]$ and the constraint is $[0, 1]$, the intersected output is $[0, 1]$.

3. **Backward pass**: Propagate the tightened output *backwards* through each operation, using inverse interval operations. This tightens the intervals on the input variables.

For example, if we know $z = x + y$, $z \in [0, 1]$, $x \in [{-1}, 3]$ and $y \in [{-1}, 3]$, then the backward step deduces $x \in [{-1}, 2]$ and $y \in [{-1}, 2]$, since $x$ cannot exceed $1 - ({-1}) = 2$ given the constraint on $z$.

### Creating a contractor

```julia
using IntervalArithmetic, IntervalConstraintProgramming, Symbolics

vars = @variables x, y
C = Contractor(x^2 + y^2, vars)
```

Calling the contractor on a box returns the contracted box:

```julia
X = IntervalBox(-5..5, 2)

C(X)                        # contract with default constraint [0, 0]
C(X, interval(0, 1))        # contract with constraint [0, 1]
```

Contractors are useful on their own when you want to find the set where an expression takes a particular value (or range of values). However, they do not distinguish the *inside* of a set from the *outside* --- that is what separators do.


## Separators

A **separator** $S$ extends the idea of a contractor to classify regions as **inner** (satisfying the constraint), **outer** (violating the constraint), or **boundary** (undetermined).

Given a constraint like $x^2 + y^2 \le 1$, a separator applied to a box $X$ returns three boxes:

- **inner**: a box guaranteed to lie *inside* the feasible set (where the constraint is satisfied)
- **outer**: a box guaranteed to contain the *outside* (where the constraint is violated)
- **boundary**: a box containing the boundary of the constraint set, where the status is unknown

```
boundary, inner, outer = S(X)
```

The fundamental guarantee is:

> Every point in $X$ that satisfies the constraint lies in `inner`.
> Every point in $X$ that violates the constraint lies in `outer`.
> The `boundary` box contains all points whose status is uncertain.

### Creating a separator

The main way to create a separator is with the `constraint` function (or equivalently `separator`):

```julia
using IntervalArithmetic, IntervalArithmetic.Symbols
using IntervalConstraintProgramming, Symbolics

vars = @variables x, y

S = constraint(x^2 + y^2 <= 1, vars)
```

The constraint is automatically normalized: `x^2 + y^2 <= 1` becomes `x^2 + y^2 - 1` with constraint interval $[-\infty, 0]$.

You can use any of the standard comparison operators:

| Constraint syntax               | Meaning                                   |
|---------------------------------|-------------------------------------------|
| `constraint(expr <= val, vars)` | $\text{expr} \le \text{val}$              |
| `constraint(expr >= val, vars)` | $\text{expr} \ge \text{val}$              |
| `constraint(expr ~ val, vars)`  | $\text{expr} = \text{val}$ (equality)     |

You can also use the `in` operator ($\in$) with an interval:

```julia
S = constraint(x^2 + y^2 in interval(1, 3), vars)
```

This is equivalent to $1 \le x^2 + y^2 \le 3$.

### Applying a separator

```julia
X = IntervalBox(-5..5, 2)

boundary, inner, outer = S(X)
```

For a large box like $[-5, 5]^2$, the contractor can only tighten slightly. The real power comes from combining separators with the **paving algorithm**.

## Paving: finding the feasible set

The `pave` function recursively bisects the domain and applies a separator at each step. Boxes that are proved to be inside the constraint set are collected as the **inner** approximation; boxes that cannot be classified at the given tolerance are collected as the **boundary**:

```julia
X = IntervalBox(-5..5, 2)
S = constraint(x^2 + y^2 <= 1, vars)

inner, boundary = pave(X, S, 0.05)
```

The third argument is the **tolerance**: bisection stops when a boundary box has diameter smaller than this value.

The result gives rigorous guarantees:
- Every point in an `inner` box satisfies the constraint.
- Every point *not* covered by `inner` or `boundary` boxes violates the constraint.
- Decreasing the tolerance gives a sharper approximation at the cost of more computation.

### Plotting the result

```julia
using Plots

plot(collect.(inner), aspectratio=1, lw=0, label="inner")
plot!(collect.(boundary), aspectratio=1, lw=0, label="boundary")
```

## Combining separators: set operations

Separators can be combined using set-theoretic operations to describe more complex feasible sets.

### Intersection ($\sqcap$)

The intersection of two separators gives the set of points satisfying *both* constraints:

```julia
S1 = constraint(x^2 + y^2 >= 1, vars)
S2 = constraint(x^2 + y^2 <= 3, vars)

S = S1 ⊓ S2    # type \sqcap<TAB> in Julia
```

This defines the annular region $1 \le x^2 + y^2 \le 3$.

The inner contractor of `S1 ⊓ S2` is the intersection of the inner contractors, and the outer contractor is the union of the outer contractors:

$$\text{inner}(S_1 \sqcap S_2) = \text{inner}(S_1) \sqcap \text{inner}(S_2)$$
$$\text{outer}(S_1 \sqcap S_2) = \text{outer}(S_1) \sqcup \text{outer}(S_2)$$

### Union ($\sqcup$)

The union gives the set of points satisfying *either* constraint:

```julia
S = S1 ⊔ S2    # type \sqcup<TAB> in Julia
```

$$\text{inner}(S_1 \sqcup S_2) = \text{inner}(S_1) \sqcup \text{inner}(S_2)$$
$$\text{outer}(S_1 \sqcup S_2) = \text{outer}(S_1) \sqcap \text{outer}(S_2)$$


### Complement (`!`)

The complement swaps inner and outer:

```julia
S_complement = !S
```

### Set difference and symmetric difference

```julia
S_diff = setdiff(S1, S2)      # S1 and not S2
S_sym  = symdiff(S1, S2)      # in one but not both
```

These are defined in terms of the basic operations:
- `setdiff(S1, S2)` = `S1 ⊓ !S2`
- `symdiff(S1, S2)` = `setdiff(S1, S2) ⊔ setdiff(S2, S1)`

## Complete example

Here is a complete example that finds the intersection of an ellipse and a rotated constraint:

```julia
using IntervalArithmetic, IntervalArithmetic.Symbols
using IntervalConstraintProgramming
using IntervalBoxes
using Symbolics

vars = @variables x, y

# An elliptical region
C1 = constraint(x^2 + 2y^2 >= 1, vars)

# A second constraint
C2 = constraint(x^2 + y^2 + x * y <= 3, vars)

# Intersection: points satisfying both constraints
C = C1 ⊓ C2

# Pave the domain
X = IntervalBox(-5..5, 2)
inner, boundary = pave(X, C, 0.05)

# Visualize
using Plots
plot(collect.(inner), aspectratio=1, lw=0, label="inner")
plot!(collect.(boundary), aspectratio=1, lw=0, label="boundary")
```

## How it all fits together

The pipeline from a symbolic constraint to a paving is:

1. **Symbolic expression** $\to$ normalized form $f(\mathbf{x}) \in [a, b]$
2. **Forward--backward contractor** compiled from the expression via [ReversePropagation.jl](https://github.com/JuliaIntervals/ReversePropagation.jl)
3. **Separator** wraps the contractor and classifies regions as inner, outer, or boundary
4. **Paving algorithm** recursively bisects and applies the separator to build a rigorous approximation of the feasible set

For more details on the internal compilation pipeline, see the [Architecture](architecture.md) page.

## References

- Jaulin, L., Kieffer, M., Didrit, O., and Walter, E. (2001). *Applied Interval Analysis*. Springer.
- Jaulin, L. and Desrochers, B. (2014). Introduction to the Algebra of Separators with Application to Path Planning. *Engineering Applications of Artificial Intelligence*, **33**, 141--147.
