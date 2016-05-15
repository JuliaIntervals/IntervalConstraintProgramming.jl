using ValidatedNumerics
using ConstraintPropagation

S = @separator x^2 + y^2 <= 1
X = IntervalBox(-10..10, -10..10)

@time inner, boundary = set_inversion(S, X)

include("draw_boxes.jl")

draw_boxes(inner, "green", 1)
draw_boxes(boundary, "grey", 0.2)
axis("image")
