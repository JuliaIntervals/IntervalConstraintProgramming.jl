

function bisect(X::Interval)
    m = mid(X)
    return ( Interval(X.lo, m), Interval(m, X.hi) )
end


function bisect(X::IntervalBox)
    i = findmax([diam(x) for x in X])[2]  # find largest

    x1, x2 = bisect(X[i])

    # the following is ugly -- replace by iterators once https://github.com/JuliaLang/julia/pull/15516
    # has landed?
    # X1 = IntervalBox(X[1:i-1]..., x1, X[i+1:end]...)  # insert x1 in i'th place
    # X2 = IntervalBox(X[1:i-1]..., x2, X[i+1:end]...)
    X1 = setindex(X, x1, i)
    X2 = setindex(X, x2, i)

    return (X1, X2)
end

doc"""
`pave` takes the given working list of boxes and splits them into inner and boundary
lists with the given separator
"""
function pave{N,T}(S::Separator, working::Vector{IntervalBox{N,T}}, ϵ)

    inner_list = SubPaving{N,T}()
    boundary_list = SubPaving{N,T}()

    while !isempty(working)

        X = pop!(working)

        inner, outer = S(X)   # here inner and outer are reversed compared to Jaulin
        # S(X) returns the pair (contractor with respect to the inside of the constraing, contractor with respect to outside)

        inner2 = IntervalBox(inner)
        outer2 = IntervalBox(outer)

        inside_list = setdiff(X, outer2)

        if length(inside_list) > 0
            append!(inner_list, inside_list)
        end


        boundary = inner2 ∩ outer2

        if isempty(boundary)
            continue
        end

        if diam(boundary) < ϵ
            push!(boundary_list, boundary)

        else
            push!(working, bisect(boundary)...)
        end

    end

    return inner_list, boundary_list

end


doc"""
    setinverse(S::Separator, domain::IntervalBox, eps)`

Find the subset of `domain` defined by the constraints specified by the separator `S`.
Returns (sub)pavings `inner` and `boundary`, i.e. lists of `IntervalBox`.
"""
function setinverse{N,T}(S::Separator, X::IntervalBox{N,T}, ϵ = 1e-2)

    inner_list, boundary_list = pave(S, [X], ϵ)

    return Paving{N,T}(S, inner_list, boundary_list, ϵ)

end


doc"""Refine a paving to tolerance ϵ"""
function refine!(P::Paving, ϵ = 1e-2)
    if P.ϵ <= ϵ  # already refined
        return
    end

    new_inner, new_boundary = pave(P.separator, P.boundary, ϵ)

    append!(P.inner, new_inner)
    P.boundary = new_boundary
    P.ϵ = ϵ
end
