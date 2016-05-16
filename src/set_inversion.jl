

function bisect(X::Interval)
    m = mid(X)
    return [Interval(X.lo, m), Interval(m, X.hi)]
end


function bisect(X::IntervalBox)
    i = findmax([diam(x) for x in X])[2]  # find largest

    x1, x2 = bisect(X[i])

    # the following is ugly -- replace by iterators once https://github.com/JuliaLang/julia/pull/15516
    # has landed?
    X1 = tuple(X[1:i-1]..., x1, X[i+1:end]...)  # insert x1 in i'th place
    X2 = tuple(X[1:i-1]..., x2, X[i+1:end]...)

    return [X1, X2]
end



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
