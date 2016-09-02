typealias SubPaving{N,T} Vector{IntervalBox{N,T}}

type Paving{N,T}
    separator::Separator
    inner::SubPaving{N,T}
    boundary::SubPaving{N,T}
    ϵ::Float64
end

function show{N,T}(io::IO, p::Paving{N,T})
    print(io, """Paving:
                 - tolerance ϵ = $(p.ϵ)
                 - inner approx. of length $(length(p.inner))
                 - boundary approx. of length $(length(p.boundary))"""
              )
end
