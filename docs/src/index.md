# IntervalConstraintProgramming.jl

This Julia package allows you to specify a set of **constraints** on real-valued variables, given by (in)equalities, and
rigorously calculate inner and outer approximations to the *feasible set*,
i.e. the set that satisfies the constraints.

This uses interval arithmetic provided by
[`IntervalArithmetic.jl`](https://github.com/JuliaIntervals/IntervalArithmetic.jl),
in particular multi-dimensional `IntervalBox`es, i.e. Cartesian products of one-dimensional intervals.

To do this, *interval constraint programming* is used, in particular the
so-called "forward--backward contractor". This is implemented in terms of *separators*; see
[Jaulin & Desrochers (2014)](https://doi.org/10.1016/j.engappai.2014.04.010).

## Quick start

```julia
using IntervalArithmetic, IntervalArithmetic.Symbols
using IntervalConstraintProgramming
using IntervalBoxes
using Symbolics

vars = @variables x, y

# Create separators from constraints
C1 = constraint(x^2 + 2y^2 >= 1, vars)
C2 = constraint(x^2 + y^2 + x * y <= 3, vars)

# Combine with intersection
C = C1 ⊓ C2

# Pave the domain
X = IntervalBox(-5..5, 2)
inner, boundary = pave(X, C, 0.05)
```

## Plotting the result

```julia
using Plots

plot(collect.(inner), aspectratio=1, lw=0, label="inner")
plot!(collect.(boundary), aspectratio=1, lw=0, label="boundary")
```

The inner (blue) region is **rigorously** guaranteed to lie *inside* the feasible set.
The white region is guaranteed to lie *outside* the set.
The boundary (red) region lies on the boundary, where the status is unknown at the given tolerance.

## Set operations

Separators may be combined using the operators `!` (complement), `⊓` (intersection) and `⊔` (union) to build
more complicated sets. See the [Contractors and Separators](@ref) page for details.

## Learn more

- [Contractors and Separators](contractors_and_separators.md) -- detailed explanation of the key concepts
- [Architecture](architecture.md) -- how the internal pipeline works
- [API](api.md) -- function and type reference

## References

- *Applied Interval Analysis*, Luc Jaulin, Michel Kieffer, Olivier Didrit, Eric Walter (2001)
- Introduction to the Algebra of Separators with Application to Path Planning, Luc Jaulin and Benoît Desrochers, *Engineering Applications of Artificial Intelligence* **33**, 141--147 (2014)
