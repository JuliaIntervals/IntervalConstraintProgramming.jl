
"""
`pave` takes the given working list of boxes and splits them into inner and boundary
lists with the given separator
"""
function pave(S::Separator, working::Vector{IntervalBox{N,T}}, ϵ, bisection_point=nothing) where {N,T}

    inner_list = SubPaving{N,T}()
    boundary_list = SubPaving{N,T}()

    while !isempty(working)

        X = pop!(working)

        inner, outer = S(X)   # here inner and outer are reversed compared to Jaulin
        # S(X) returns the pair (contractor with respect to the inside of the constraing, contractor with respect to outside)

        #@show X, outer
        inside_list = setdiff(X, outer)

        if length(inside_list) > 0
            append!(inner_list, inside_list)
        end


        boundary = inner ∩ outer

        if isempty(boundary)
            continue
        end

        if diam(boundary) < ϵ
            push!(boundary_list, boundary)

        else
            if bisection_point == nothing
                push!(working, bisect(boundary)...)
            else
                push!(working, bisect(boundary, bisection_point)...)
            end

        end

    end

    return inner_list, boundary_list

end


"""
    pave(S::Separator, domain::IntervalBox, eps)`

Find the subset of `domain` defined by the constraints specified by the separator `S`.
Returns (sub)pavings `inner` and `boundary`, i.e. lists of `IntervalBox`.
"""
function pave(S::Separator, X::IntervalBox{N,T}, ϵ = 1e-2, bisection_point=nothing) where {N,T}

    inner_list, boundary_list = pave(S, [X], ϵ, bisection_point)

    return Paving(S, inner_list, boundary_list, ϵ)

end

#
# """Refine a paving to tolerance ϵ"""
# function refine!(P::Paving, ϵ = 1e-2)
#     if P.ϵ <= ϵ  # already refined
#         return
#     end
#
#     new_inner, new_boundary = pave(P.separator, P.boundary, ϵ)
#
#     append!(P.inner, new_inner)
#     P.boundary = new_boundary
#     P.ϵ = ϵ
# end
