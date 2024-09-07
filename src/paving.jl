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
