

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
function set_inversion(S::Separator, X::IntervalBox, ϵ = 1e-2)
    working = [X]  # stack of boxes that are waiting to be processed

    inner_list = typeof(X)[]
    boundary_list = typeof(X)[]

    while !isempty(working)
        X = pop!(working)

        inner, outer = S(X)   # here inner and outer are reversed compared to Jaulin
        # S(X) returns the pair (contractor with respect to the inside of the constraing, contractor with respect to outside)
        inner2 = IntervalBox(inner)
        outer2 = IntervalBox(outer)

        #@show inner2, outer2

        inside = setdiff(X, outer2)

        @assert inside ⊆ X
        if !(isempty(inside))
            push!(inner_list, inside)
        end


        boundary = inner2 ∩ outer2

        #if !(boundary ⊆ inside)
            @show X
            @show inner2
            @show outer2
            @show inside
            @show boundary
            println()
            #exit(1)
        #end

        if diam(boundary) < ϵ
            push!(boundary_list, boundary)

        else
            append!(working, bisect(boundary))
        end

    end

    inner_list, boundary_list

end
