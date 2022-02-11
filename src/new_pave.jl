function pave(X, C::Contractor, ϵ=0.1)
    working = [X]
    paving = typeof(X)[]

    while !isempty(working)
        X = pop!(working)
		
		if isempty(X)
            continue
        end

        X = C(X, 0..0)

		if isempty(X)
            continue
        end

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
function pave(X, S::AbstractSeparator, ϵ=0.1)
    working = [X]
	inner_paving = typeof(X)[]
    boundary_paving = typeof(X)[]

    while !isempty(working)
	
        X = pop!(working)
		
		if isempty(X)
            continue
        end
		
		if any(any.(isnan, X))  # hack to check empty
			continue
		end
		
		# @show X


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
		
		push!(working, bisect(boundary)...)

    end

    return (inner=inner_paving, boundary=boundary_paving)
end

pave(X, S::ConstraintProblem, ϵ=0.1) = pave(X, S.separator, ϵ)


solve = pave