# IntervalConstraintProgramming.jl



This Julia package allows us to specify a set of constraints on real-valued variables, 
given by inequalities, and 
rigorously calculate (inner and outer approximations to) the *feasible set*, 
i.e. the set that satisfies the constraints.

The package is based on interval arithmetic using the author's 
[`ValidatedNumerics.jl`](https://github.com/dpsanders/ValidatedNumerics.jl) package,
in particular multi-dimensional `IntervalBox`es (i.e. Cartesian products of one-dimensional intervals).

The goal is to impose constraints, given by inequalities, and find the set that
satisfies the constraints, known as the **feasible set**.

The method used to do this is known as *interval constraint programming*, in particular the 
so-called "forward--backward contractor". This is implemented in terms of *separators*; see 
[Jaulin & Desrochers].

## Constraints
First we define a constraint using the `@constraint` macro:
```julia
S = @constraint x^2 + y^2 <= 1
```
and an initial interval in the $x$--$y$ plane, `X`:
```julia
x = y = -100..100
X = IntervalBox(x, y)
```

The `@constraint` macro defines an object `S`, of type `Separator`.
This is a function which,
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

## Set inversion: finding the feasible set

To make progress, we must recursively bisect and apply the contractors, keeping
track of the region proved to be inside the feasible set, and the region that is
on the boundary ("both inside and outside"). This is done by the `setinverse` function,
that takes a separator, a domain to search inside, and an optional tolerance:

```julia
julia> S = @constraint 1 <= x^2 + y^2 <= 3
julia> inner, boundary = setinverse(S, X, 0.125);
```

We may draw the result using the code in the `draw_boxes` file in the examples directory,
which uses `PyPlot.jl`:
```julia
julia> filename = joinpath(Pkg.dir("IntervalConstraintProgramming"), "examples", "draw_boxes.jl");
julia> include(filename);

julia> draw_boxes(inner, "green", 0.5, 1)
julia> draw_boxes(boundary, "grey", 0.2)
```
The second argument is the color; the third (optional) is the alpha value (transparency);
and the fourth is the linewidth (default is 0).

The output should look like this:

![Ring](examples/ring.png)


The green boxes have been **rigorously** proved to be contained within the feasible set,
while the grey boxes show those on the boundary, whose status is unknown.
The white area outside and inside the ring has been **rigorously** proved to be outside
the feasible set.

## Set operations
Separators may be combined using the operators `!` (complement), `∩` and `∪` to make
more complicated sets; see the [notebook](examples/Set inversion with separators examples.ipynb) for several examples.

## Author

- [David P. Sanders](http://sistemas.fciencias.unam.mx/~dsanders),
Departamento de Física, Facultad de Ciencias, Universidad Nacional Autónoma de México (UNAM)


## References:
- *Applied Interval Analysis*, Luc Jaulin, Michel Kieffer, Olivier Didrit, Eric Walter (2001)
- Introduction to the Algebra of Separators with Application to Path Planning, Luc Jaulin and Benoît Desrochers,
*Engineering Applications of Artificial Intelligence* **33**, 141–147 (2014)

## Acknowledements
Financial support is acknowledged from DGAPA-UNAM PAPIME grants PE-105911 and PE-107114, and DGAPA-UNAM PAPIIT grant IN-117214, and from a CONACYT-Mexico sabbatical fellowship. The author thanks Alan Edelman and the Julia group for hospitality during his sabbatical visit. He also thanks Luc Jaulin and Jordan Ninin for the [IAMOOC](http://iamooc.ensta-bretagne.fr/) online course, which introduced him to this subject.
