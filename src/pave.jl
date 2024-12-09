
const SubPaving{N,T} = Vector{IntervalBox{N,T}}

struct Paving{N,T}
    separator::Separator   # parametrize!
    inner::SubPaving{N,T}
    boundary::SubPaving{N,T}
    ϵ::Float64
end


function setdiff(x::IntervalBox{N,T}, subpaving::SubPaving{N,T}) where {N,T}
    working = [x]
    new_working = IntervalBox{N,T}[]

    local have_split

    for y in subpaving
        for x in working
            have_split = false

            diff = setdiff(x, y)

            if diff != [x]
                have_split = true
                append!(new_working, diff)
            end
        end

        !have_split && push!(new_working, x)

        working = new_working
        new_working = IntervalBox{N,T}[]

    end

    return working

end

setdiff(X::SubPaving{N,T}, Y::SubPaving{N,T}) where {N,T} = vcat([setdiff(x, Y) for x in X]...)

function setdiff(x::IntervalBox{N,T}, paving::Paving{N,T}) where {N,T}
    Y = setdiff(x, paving.inner)
    Z = setdiff(Y, paving.boundary)
    return Z
end


function show(io::IO, p::Paving{N,T}) where {N,T}
    print(io, """Paving:
                 - tolerance ϵ = $(p.ϵ)
                 - inner approx. of length $(length(p.inner))
                 - boundary approx. of length $(length(p.boundary))"""
              )
end


function pave(X, C::AbstractContractor, ϵ=0.1)
    working = [X]
    paving = typeof(X)[]

    while !isempty(working)
        X = pop!(working)

		isempty(X) && continue

        X = C(X)

		isempty(X) && continue

        if diam(X) < ϵ
            push!(paving, X)
            continue
        end

        push!(working, bisect(X)...)
    end

    return paving
end

"""
Find inner and outer approximations of the intersection of `X` with the
set ``S`` specified by the separator `S`.

Returns the `inner` paving (a vector of those boxes that are guaranteed to be inside ``S``) and the `boundary`
paving (boxes which have unknown status: they have neither been excluded, nor proved to
lie inside `S`).
"""
function pave(X, S::AbstractSeparator, ϵ = 0.1, bisection_point = nothing)
    working = [X]
	inner_paving = typeof(X)[]
    boundary_paving = typeof(X)[]

    while !isempty(working)

        X = pop!(working)

		isempty(X) && continue

        boundary, inner, outer = S(X)

		if outer != X
			# index = findfirst(outer .!= X)

			diff = setdiff(X, outer)
			# replace setdiff with finding the *unique* direction that shrank

			if !isempty(diff)

				append!(inner_paving, diff)

			end
		end


        if diam(boundary) < ϵ
            push!(boundary_paving, boundary)
            continue
        end

        if isnothing(bisection_point)
            push!(working, bisect(boundary)...)
        else
            push!(working, bisect(boundary, bisection_point)...)
        end

    end

    return inner_paving, boundary_paving
end

# pave(X, S::ConstraintProblem, ϵ=0.1) = pave(X, S.separator, ϵ)



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
            if isnothing(bisection_point)
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