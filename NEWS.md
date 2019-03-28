# IntervalConstraintProgramming.jl

# v1.0
## Minimum Julia version
- The minimum Julia version supported is now Julia 1.0.

## New Dependency added:  `ModelingToolkit.jl`

- By the help of `ModelingToolkit.jl` we can construct contractors and separators without the use of macros.

# v0.9
## Minimum Julia version
- The minimum Julia version supported is now Julia 0.7. The package is fully compatible with Julia 1.0.

## Functionality removed
- Pavings are now immutable, so `refine!` no longer works.


# v0.8
## Minimum Julia version
- The minimum Julia version required has been bumped to 0.6; this will be the last release to support 0.6.

# v0.7

## New dependency: `IntervalContractors.jl`

The reverse functions used for constraint propagation have been factored out into the `IntervalContractors.jl` package.

# v0.6
## Minimum Julia version
- The minimum Julia version required has been bumped to 0.5

## API change
- Objects such as `Contractor` have been simplified by putting functions and the code that generated them inside a `GeneratedFunction` type

## Dependency change
- The dependency on `ValidatedNumerics.jl` has been replaced by `IntervalArithmetic.jl` and `IntervalRootFinding.jl`

# v0.5
- API change: Contractors now have their dimension as a type parameter
- Refactoring for type stability
- Removed reference to FixedSizeArrays; everything (including `bisect`) is now provided by `IntervalArithmetic`
- Removed all functions acting directly on `Interval`s and `IntervalBox`es that should belong to `IntervalArithmetic`
- Generated code uses simpler symbols
- Example notebooks have been split out into a separate repository: https://github.com/dpsanders/IntervalConstraintProgrammingNotebooks

# v0.4
- `@function f(x) = 4x` defines a function
- Functions may be used inside constraints
- Functions may be iterated
- Functions may be multi-dimensional
- Local variables may be introduced
- Simple plotting solution for the results of `pave` using `Plots.jl` recipes
(via `IntervalArithmetic.jl`):
```
using Plots
gr()  # preferred (fast) backed for `Plots.jl`
plot(paving.inner)
plot!(paving.boundary)
```
- Major internals rewrite
- Unary minus and `power_rev` with odd powers now work correctly
- Examples updated
- Basic documentation using `Documenter.jl`


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
