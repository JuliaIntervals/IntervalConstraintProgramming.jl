# IntervalConstraintProgramming.jl

[![Build Status](https://travis-ci.org/JuliaIntervals/IntervalConstraintProgramming.jl.svg?branch=master)](https://travis-ci.org/dpsanders/IntervalConstraintProgramming.jl)

This Julia package allows us to specify a set of constraints on real-valued variables,
given by inequalities, and
rigorously calculate (inner and outer approximations to) the *feasible set*,
i.e. the set that satisfies the constraints.

The package is based on interval arithmetic using the
[`IntervalArithmetic.jl`](https://github.com/JuliaIntervals/IntervalArithmetic.jl) package (co-written by the author),
in particular multi-dimensional `IntervalBox`es (i.e. Cartesian products of one-dimensional intervals).

## Documentation
Documentation for the package is available [here](http://juliaintervals.github.io/IntervalConstraintProgramming.jl/latest/).

The best way to learn how to use the package is to look at the example notebooks, available in a separate repository [here](https://github.com/JuliaIntervals/IntervalConstraintProgrammingNotebooks).


## Author

- [David P. Sanders](http://sistemas.fciencias.unam.mx/~dsanders),
Departamento de Física, Facultad de Ciencias, Universidad Nacional Autónoma de México (UNAM)


## References:
- *Applied Interval Analysis*, Luc Jaulin, Michel Kieffer, Olivier Didrit, Eric Walter (2001)
- Introduction to the Algebra of Separators with Application to Path Planning, Luc Jaulin and Benoît Desrochers, *Engineering Applications of Artificial Intelligence* **33**, 141–147 (2014)

## Acknowledements
Financial support is acknowledged from DGAPA-UNAM PAPIME grants PE-105911 and PE-107114, and DGAPA-UNAM PAPIIT grant IN-117214, and from a CONACYT-Mexico sabbatical fellowship. The author thanks Alan Edelman and the Julia group for hospitality during his sabbatical visit. He also thanks Luc Jaulin and Jordan Ninin for the [IAMOOC](http://iamooc.ensta-bretagne.fr/) online course, which introduced him to this subject.
