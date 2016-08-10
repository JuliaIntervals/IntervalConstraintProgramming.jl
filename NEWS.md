# IntervalConstraintProgramming.jl

# v0.3
- Renamed `setinverse` to `pave`

- External constants may now be used in `@constraint`, e.g.
```
a, b = 1, 2
C = @constraint (x-$a)^2 + (y-$b)^2
```
The constraint will *not* change if the constants are changed, but may be
updated (changed) by calling the same `@constraint` command again.  

# v0.2
- `setinverse` now returns an object of type `Paving`  [#17](https://github.com/dpsanders/IntervalConstraintProgramming.jl/pull/17)

- `refine!` function added to refine an existing `Paving` to a lower tolerance  [#17](https://github.com/dpsanders/IntervalConstraintProgramming.jl/pull/17)

- `vol` has been renamed to `Vol`, and is applied directly to a `Paving` object.

- Internal variable names in generated code are now of form `_z_1_` instead of `z1`
to eliminate collisions with user-defined variables [#20](https://github.com/dpsanders/IntervalConstraintProgramming.jl/pull/20)


## v0.1.1
- Add `sqrtRev` reverse-mode function

- Add solid torus example, including 3D visualization with GLVisualize

- Tests pass with Julia 0.5


# v0.1

- Basic functionality working (separators and `setinverse`)

- `Vol` function calculates the Volume of the set produced by `setinverse`; returns
objects of type `Vol` parametrised by the dimension $d$ of the set (i.e. $d$-dimensional
    Lebesgue measure), which are interval ranges
