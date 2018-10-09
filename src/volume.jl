import Base:
    +, show, *

"""N-dimensional Volume with lower and upper bounds"""
struct Vol{N,T}
    bounds::Interval{T}
end


Vol_name(i::Integer) = i == 1 ? "length" : i == 2 ? "area" : i == 3 ? "Volume" : "hyper-Volume"

show(io::IO, v::Vol{N,T}) where {N,T} = print(io, "$N-dimensional $(Vol_name(N)): $(v.bounds)")


Vol(X::IntervalBox{N,T}) where {N,T} = Vol{N,T}(prod([Interval(x.hi) - Interval(x.lo) for x in X]))

Vol(x::Interval{T}) where {T} = Vol(IntervalBox(x))


+(v::Vol{N,T}, w::Vol{N,T}) where {N,T} = Vol{N,T}(v.bounds + w.bounds)

*(v::Vol{N1,T}, w::Vol{N2,T}) where {N1,N2,T} = Vol{N1+N2,T}(v.bounds * w.bounds)


Vol(XX::SubPaving{N,T}) where {N,T} = sum([Vol(X) for X in XX])

function Vol(P::Paving{N,T}) where {N,T}
    Vin = Vol(P.inner)
    Vout = Vin + Vol(P.boundary)

    return Vol{N,T}(hull(Vin.bounds, Vout.bounds))
end
