# IntervalConstraintProgramming.jl

[![Build Status](https://github.com/JuliaIntervals/IntervalConstraintProgramming.jl/workflows/CI/badge.svg)](https://github.com/JuliaIntervals/IntervalConstraintProgramming.jl/actions/workflows/CI.yml)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliaintervals.github.io/pages/packages/intervalconstraintprogramming/)

This Julia package allows us to specify a set of constraints on real-valued variables,
given by inequalities, and
rigorously calculate (inner and outer approximations to) the *feasible set*,
i.e. the set that satisfies the constraints.

The package is based on interval arithmetic using the
[`IntervalArithmetic.jl`](https://github.com/JuliaIntervals/IntervalArithmetic.jl) package (co-written by the author),
in particular multi-dimensional `IntervalBox`es (i.e. Cartesian products of one-dimensional intervals).

<!-- ## Documentation
Documentation for the package is available [here](https://juliaintervals.github.io/pages/packages/intervalconstraintprogramming/).

The best way to learn how to use the package is to look at the tutorial, available in the organisation webpage [here](https://juliaintervals.github.io/pages/tutorials/tutorialConstraintProgramming/). -->

## Basic usage

```jl
using IntervalArithmetic, IntervalArithmetic.Symbols
using IntervalConstraintProgramming
using IntervalBoxes
using Symbolics

vars = @variables x, y

C1 = constraint(x^2 + 2y^2 ≥ 1, vars)
C2 = constraint(x^2 + y^2 + x * y ≤ 3, vars)
C = C1 ⊓ C2

X = IntervalBox(-5..5, 2)

tolerance = 0.05
inner, boundary = pave(X, C, tolerance)

# plot the result:
using Plots

plot(collect.(inner), aspectratio=1, lw=0, label="inner");
plot!(collect.(boundary), aspectratio=1, lw=0, label="boundary")
```

- The inner, blue, region is guaranteed to lie *inside* the constraint set.
- The outer, white, region is guaranteed to lie *outside* the constraint set.
- The in-between, red, region is not known at this tolerance.

![Inner and outer ellipse](ellipses.svg?)




## Author

- [David P. Sanders](http://sistemas.fciencias.unam.mx/~dsanders),
Departamento de Física, Facultad de Ciencias, Universidad Nacional Autónoma de México (UNAM)


## References:
- *Applied Interval Analysis*, Luc Jaulin, Michel Kieffer, Olivier Didrit, Eric Walter (2001)
- Introduction to the Algebra of Separators with Application to Path Planning, Luc Jaulin and Benoît Desrochers, *Engineering Applications of Artificial Intelligence* **33**, 141–147 (2014)

## Acknowledements
Financial support is acknowledged from DGAPA-UNAM PAPIME grants PE-105911 and PE-107114, and DGAPA-UNAM PAPIIT grant IN-117214, and from a CONACYT-Mexico sabbatical fellowship. The author thanks Alan Edelman and the Julia group for hospitality during his sabbatical visit. He also thanks Luc Jaulin and Jordan Ninin for the [IAMOOC](http://iamooc.ensta-bretagne.fr/) online course, which introduced him to this subject.
