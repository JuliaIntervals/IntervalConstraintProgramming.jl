# IntervalConstraintProgramming.jl

## v0.1.1
- Add `sqrtRev` reverse-mode function

- Add solid torus example, including 3D visualization with GLVisualize

- Tests pass with Julia 0.5


# v0.1

- Basic functionality working (separators and `setinverse`)

- `vol` function calculates the volume of the set produced by `setinverse`; returns
objects of type `Vol` parametrised by the dimension $d$ of the set (i.e. $d$-dimensional
    Lebesgue measure), which are interval ranges
