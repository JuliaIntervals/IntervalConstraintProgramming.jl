using Makie
using Colors

using IntervalConstraintProgramming, IntervalArithmetic

## Constraint programming
solid_torus = @constraint (3 - sqrt(x^2 + y^2))^2 + z^2 <= 1

half_space = @constraint (x + y) + z <= 1

x = interval(-5, 5)
Y = IntervalBox(x, 3)

@time paving = pave(solid_torus ⊓ half_space, Y, 0.1);

inner = paving.inner
boundary = paving.boundary;


## Makie plotting set-up
positions = Point{3, Float32}[Point3(mid(x)...) for x in vcat(inner, boundary)]
scales = Vec3f0[Vec3f0([diam(x) for x in xx]) for xx in vcat(inner, boundary)]

zs = Float32[x[3] for x in positions]
minz = minimum(zs)
maxz = maximum(zs)

xs = Float32[x[1] for x in positions]
minx = minimum(xs)
maxx = maximum(xs)

colors1 = RGBA{Float32}[RGBA( (zs[i]-minz)/(maxz-minz), (xs[i]-minx)/(maxx-minx), 0f0, 0.1f0)
        for i in 1:length(inner)];
colors2 = RGBA{Float32}[RGBA( 0.5f0, 0.5f0, 0.5f0, 0.02f0) for x in boundary];
colors = vcat(colors1, colors2);

## Makie plotting:
cube = Rect{3, Float32}(Vec3f0(-0.5, -0.5, -0.5), Vec3f0(1, 1, 1))
# centre, widths

meshscatter(positions, marker=cube, scale=scales, color=colors, transparency=true)
