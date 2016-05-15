
#
#@enum WHERE IN=1 OUT=-1 UNCERTAIN=0


# function inclusion(f::Function, X::IntervalBox, Y::Interval)
#
#     image = f(X)
#
#     if isempty(image)
#         return OUT  # HACK
#     end
#
#     if image ⊆ Y
#         IN
#
#     elseif isempty(image ∩ Y)
#         OUT
#
#     else
#         UNCERTAIN
#     end
# end
#
# inclusion(f::Function, y::AbstractFloat) = inclusion(f, @interval(y))
#
# doc"""`inclusion(f::Function, Y::Interval)
#
# Gives inclusion function for `f(X) ⊆ Y`
#
# `f(X)` takes `X::IntervalBox` and returns an `Interval`."""
# inclusion(f::Function, Y::Interval) = X -> inclusion(f, X, Y)
#
#
# ring(X, a, b) = (X[1]-a)^2 + (X[2]-b)^2


function bisect(X::Interval)
    m = mid(X)
    return [Interval(X.lo, m), Interval(m, X.hi)]
end

function bisect(X::IntervalBox)
    which = findmax(map(diam, X.intervals))[2]  # bisect largest

    x1, x2 = bisect(X.intervals[which])

    # replace the following by iterators once https://github.com/JuliaLang/julia/pull/15516
    # has landed?

    intervals = X.intervals

    # the following is pretty horrible...
    X1 = tuple(intervals[1:which-1]..., x1, intervals[which+1:end]...)
    X2 = tuple(intervals[1:which-1]..., x2, intervals[which+1:end]...)

    [X1, X2]

end

ValidatedNumerics.diam(X::IntervalBox) = maximum(map(diam, X))

# import Base.setdiff
# function setdiff(x::Interval, y::Interval)
#
# end

doc"""
    set_inversion(S::Separator, X::IntervalBox, eps)`

Find the domain defined by the constraints represented by the separator `S`.
Returns pavings `inner` and `boundary`.
"""
function set_inversion(S::Separator, X::IntervalBox, ϵ=1e-2)
    working = [X]

    inner_list = typeof(X)[]
    boundary_list = typeof(X)[]

    while length(working) > 0
        X = pop!(working)

        if diam(X) < ϵ
            push!(boundary_list, X)
            continue
        end

        # should use setdiff to remove boundary part from inner part?

        inner, outer = S(X.intervals)
        inner2 = IntervalBox(inner)
        outer2 = IntervalBox(outer)

        boundary = inner2 ∩ outer2
        if !isempty(boundary)
            append!(working, bisect(X))

        elseif isempty(outer2)
            push!(inner_list, X)
        end

    end

    inner_list, boundary_list

end



#include("draw_boxes.jl")

print("""
Usage:

@time inner, boundary = set_inversion(S, X, eps)

draw_boxes(inner, "green", 1)
draw_boxes(boundary, "grey", 0.2)
axis("image")
""")
