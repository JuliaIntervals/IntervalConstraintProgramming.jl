using ValidatedNumerics
using IntervalConstraintProgramming

S = @separator 1 <= x^2 + y^2 <= 3
X = IntervalBox(-10..10, -10..10)

@time inner, boundary = pave(S, X, 0.125)

@show length(inner), length(boundary)

include("draw_boxes.jl")

draw_boxes(inner, "green", 0.5, 1)
draw_boxes(boundary, "grey", 0.2)
axis("image")  # set aspect ratio
