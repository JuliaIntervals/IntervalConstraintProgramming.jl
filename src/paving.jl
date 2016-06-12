typealias SubPaving{N,T} Vector{IntervalBox{N,T}}

type Paving{N,T}
    separator::Separator
    inner::SubPaving{N,T}
    boundary::SubPaving{N,T}
    ϵ::Float64
end
