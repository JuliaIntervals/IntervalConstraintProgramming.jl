import Base:
    +, show, *

doc"""N-dimensional volume with lower and upper bounds"""
immutable Vol{N,T}
    bounds::Interval{T}
end

volname(i::Integer) = i == 1 ? "length" : i == 2 ? "area" : i == 3 ? "volume" : "hyper-volume"

show{N,T}(io::IO, v::Vol{N,T}) = print(io, "$N-dimensional $(volname(N)): $(v.bounds)")


vol{N,T}(X::IntervalBox{N,T}) = Vol{N,T}(prod([Interval(x.hi) - Interval(x.lo) for x in X]))

vol{T}(x::Interval{T}) = vol(IntervalBox(x))


+{N,T}(v::Vol{N,T}, w::Vol{N,T}) = Vol{N,T}(v.bounds + w.bounds)

*{N1,N2,T}(v::Vol{N1,T}, w::Vol{N2,T}) = Vol{N1+N2,T}(v.bounds * w.bounds)


vol{N,T}(XX::Vector{IntervalBox{N,T}}) = sum([vol(X) for X in XX])

function vol{N,T}(S::Separator, domain::IntervalBox{N,T}, eps=0.01)
    inner, boundary = setinverse(S, domain, eps)
    Vin = vol(inner)
    Vout = Vin + vol(boundary)

    return Vol{N,T}(hull(Vin.bounds, Vout.bounds))
end
