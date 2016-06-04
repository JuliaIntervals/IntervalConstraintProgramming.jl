# Taken from GLVisualize example "Meshcreation"

using GLVisualize, GeometryTypes, GLAbstraction, Colors

println("Visualization packages loaded.")

using ValidatedNumerics
using ConstraintProgramming

println("Constraint packages loaded.")

S1 = @constraint 3 <= x^2 + y^2 + z^2 <= 4
S2 = @constraint 2 <= (x-0.5)^2 + (y-0.4)^2 + (z-0.3)^2 <= 4
S = S1 ∩ S2

X = IntervalBox(-10..10, -10..10, -10..10)

@time inner, boundary = setinverse(S, X, 0.2)
@show length(inner)

println("Set inversion finished")

function cube(X::IntervalBox, inner=true)
    lo = [x.lo for x in X]  # what's the good way to do this?
    hi = [x.hi for x in X]
    #color = Float32((hi[3] + 2.) / 4)
    #c = Float32(abs(hi[3]) / 2.)
    #mycolor = RGBA(1f0, c, c/2, 0.2f0)
    if inner
        mycolor = RGBA(1f0, 0f0, 0f0, 0.2f0)
    else
        mycolor = RGBA(0f0, 1f0, 0f0, 0.2f0)
    end
    return (HyperRectangle{3, Float32}(Vec3f0(lo), Vec3f0(hi - lo)), mycolor)
end

window = glscreen()

baselen = 0.4f0
dirlen = 2f0
# create an array of differently colored boxes in the direction of the 3 axes
cubes = map(cube, inner)
boundarycubes = [cube(x, false) for x in boundary]

# convert to an array of normal meshes
# note, that the constructor is a bit weird. GLNormalMesh takes a tuple of
# a geometry and a color. This means, the geometry will be converted to a GLNormalMesh
# and the color will be added afterwards, so the resulting type is a GLNormalColorMesh
meshes = map(GLNormalMesh, vcat(cubes, boundarycubes))
# merge them into one big mesh
# the resulting type is a GLNormalAttributeMesh, since we merged meshes with different
# attributes (colors). An array of the colors will be created and each vertex in the
# mesh will be asigned to one of the colors found there.
colored_mesh = merge(meshes)
view(visualize(colored_mesh), window)


renderloop(window)
