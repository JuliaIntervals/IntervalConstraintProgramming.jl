# `ConstraintProgramming.jl`

This package carries out "interval constraint programming".
It uses intervals from the
`ValidatedNumerics.jl`[https://github.com/dpsanders/ValidatedNumerics.jl] package,
and the multi-dimensional version, called `IntervalBox`es.

The goal is to impose constraints, given by inequalities, and find the set that
satisfies the constraints, known as the **feasible set**.

## Separators
First we define a constraint using the `@constraint` macro:
```julia
S = @constraint x^2 + y^2 <= 1
```
and an initial interval in the $x$--$y$ plane, `X`:
```julia
x = y = -100..100
X = IntervalBox(x, y)
```

The `@constraint` macro defines an object `S`, of type `Separator`,
which is basically a function. This function,
when applied to the box $X = x \times y$
in the x--y plane, applies two *contractors*, an inner one and an outer one.

The inner contractor tries to shrink down, or *contract*, the box, to the smallest subbox
of $X$ that contains the part of $X$ that satisfies the constraint; the
outer contractor tries to contract $X$ to the smallest subbox that contains the
region where the constraint is not satisfied.

When `S` is applied to the box `X`, it returns the result of the inner and outer contractors:
```julia
julia> inner, outer = S(X);

julia> inner
([-1, 1],[-1, 1])

julia> outer
([-100, 100],[-100, 100])
```

## Set inversion
To make progress, we must recursively bisect and apply the contractors, keeping
track of the region proved to be inside the feasible set, and the region that is
on the boundary ("both inside and outside"). This is done by the `set_inversion` function,
that takes a separator, an initial set, and an optional tolerance.

```julia
inner, boundary = set_inversion(S, X, 0.125);
```
We may draw the result using the code in the `draw_boxes` file in the examples directory,
which uses `PyPlot.jl`:
```julia
julia> filename = joinpath(Pkg.dir("ConstraintProgramming"), "examples", "draw_boxes.jl");
julia> include(filename);

draw_boxes(inner, "green", 0.5, 1)
```
The second argument is the color; the third (optional) is the alpha value (transparency);
and the fourth is the linewidth (default is 0).

![Ring](examples/ring.png)

## Set operations
Separators may be combined using the operators `!` (complement), `∩` and `∪` to make
more complicated sets.
