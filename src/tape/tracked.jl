const NULL_INDEX = typemin(Int)
const NULL_TAPE = InstructionTape()

mutable struct TrackedReal{V<:Real,O} <: Real #Mutable type to track the input and other variables
    value::V
    tape::InstructionTape
    index::Int
    origin::O
    (::Type{TrackedReal{V,O}}){V,O}(value, tape, index, origin) = new{V,O}(value, tape, index, origin)
    (::Type{TrackedReal{V,O}}){V,O}(value, tape) = new{V,O}(value, tape, NULL_INDEX)
    (::Type{TrackedReal{V,O}}){V,O}(value) = new{V,O}(value, NULL_TAPE, NULL_INDEX)
end

TrackedReal{V,O}(v::V, tp::InstructionTape, i::Int, o::O) = TrackedReal{V,O}(v, tp, i, o)

TrackedReal{V}(v::V, tp::InstructionTape = NULL_TAPE) = TrackedReal{V,Void}(v, tp)

immutable TrackedArray{V,N,VA} <: AbstractArray{TrackedReal{V,TrackedArray{V,N,VA}},N}
    value::VA
    tape::InstructionTape
    function (::Type{TrackedArray{V,N,VA}}){V,N,VA}(value::AbstractArray{V,N},
                                                              tape::InstructionTape)
        return new{V,N,VA}(value, tape)
    end
end

function TrackedArray{V,N}(value::AbstractArray{V,N},
                             tape::InstructionTape)
    return TrackedArray{V,N,typeof(value)}(value, tape)
end

istracked(x) = false
istracked(::TrackedReal) = true
istracked(::TrackedArray) = true
istracked{T}(::AbstractArray{T}) = T <: TrackedReal || !(isleaftype(T))

#Getters and setters
@inline value(x) = x
@inline value(x::AbstractArray) = istracked(x) ? map(value, x) : x
@inline value(t::TrackedReal) = t.value
@inline value(t::TrackedArray) = t.value

@inline valtype{V}(::TrackedReal{V}) = V
@inline valtype{V,O}(::Type{TrackedReal{V,O}}) = V
@inline valtype{V}(::TrackedArray{V}) = V
@inline valtype{V,VA,N}(::Type{TrackedArray{V,N,VA}}) = V

@inline origintype{V,O}(::TrackedReal{V,O}) = O
@inline origintype{V,O}(::Type{TrackedReal{V,O}}) = O

@inline hasorigin(x::Real) = false
@inline hasorigin(t::TrackedReal) = t.index !== NULL_INDEX

@inline hastape(x) = false
@inline hastape(t::TrackedArray) = tape(t) !== NULL_TAPE
@inline hastape(t::TrackedReal) = tape(t) !== NULL_TAPE
@inline hastape(x::AbstractArray) = tape(x) !== NULL_TAPE

@inline tape(x) = NULL_TAPE
@inline tape(t::TrackedArray) = t.tape
@inline tape(t::TrackedReal) = t.tape

function tape(x::AbstractArray)
    if istracked(x)
        for i in x
            hastape(i) && return tape(i)
        end
    end
    return NULL_TAPE
end

function tape(ts...)
    for t in ts
        hastape(t) && return tape(t)
    end
    return NULL_TAPE
end

@inline value!(t::TrackedReal, v::Real) = (t.value = v; nothing)
@inline value!(t::TrackedArray, v::AbstractArray) = (copy!(value(t), v); nothing)

function value!{N}(t::NTuple{N,Any}, v::NTuple{N,Any})
    for i in eachindex(t)
        value!(t[i], v[i])
    end
    return nothing
end

pull_value!(x) = nothing
pull_value!(t::TrackedArray) = nothing
pull_value!(t::TrackedReal) = (hasorigin(t) && value!(t, value(t.origin)[t.index]); nothing)
pull_value!(x::AbstractArray) = (istracked(x) && foreach(pull_value!, x); nothing)

capture(t::TrackedReal) = ifelse(hastape(t), t, value(t))
capture(t::TrackedArray) = t
capture(t::AbstractArray) = istracked(t) ?  map!(capture, similar(t), t) : copy(t)

Base.convert{T<:TrackedReal}(::Type{Real}, t::T) = t
Base.convert{R<:Real,T<:TrackedReal}(::Type{R}, t::T) = R(value(t))
Base.convert{T<:TrackedReal,R<:Real}(::Type{T}, x::R) = TrackedReal{valtype(T),origintype(T)}(convert(valtype(T), value(x)))

Base.convert{T<:TrackedReal}(::Type{T}, t::T) = t
Base.convert{T<:TrackedArray}(::Type{T}, t::T) = t

for R in REAL_TYPES
    @eval Base.promote_rule{V,O}(::Type{$R}, ::Type{TrackedReal{V,O}}) = TrackedReal{promote_type($R,V),O}
end

Base.promote_rule{R<:Real,V,O}(::Type{R}, ::Type{TrackedReal{V,O}}) = TrackedReal{promote_type(R,V),O}
Base.promote_rule{V1,V2,O1,O2}(::Type{TrackedReal{V1,O1}}, ::Type{TrackedReal{V2,O2}}) = TrackedReal{promote_type(V1,V2),Void}

Base.promote_array_type{T<:TrackedReal, F<:AbstractFloat}(_, ::Type{T}, ::Type{F}) = promote_type(T, F)
Base.promote_array_type{T<:TrackedReal, F<:AbstractFloat, S}(_, ::Type{T}, ::Type{F}, ::Type{S}) = S
Base.promote_array_type{F<:AbstractFloat, T<:TrackedReal}(_, ::Type{F}, ::Type{T}) = promote_type(T, F)
Base.promote_array_type{F<:AbstractFloat, T<:TrackedReal, S}(_, ::Type{F}, ::Type{T}, ::Type{S}) = S

Base.r_promote{T<:TrackedReal}(::typeof(+), t::T) = t
Base.r_promote{T<:TrackedReal}(::typeof(*), t::T) = t

import Base.getindex
function getindex(t::TrackedArray, i::Int)
    tp = tape(t)
    out = TrackedReal(value(t)[i], tape(t), i, t)
    # out = value(t)[i]
    cache = IntervalArithmetic.entireinterval()
    record!(tp, ScalarInstruction, getfield(Base, :getindex), t, value(t)[i], cache)
    # println("Recorded getindex")
    return out
end

colon2range(s, i) = i
colon2range(s, ::Colon) = s

function index_iterable{N,M}(shape::NTuple{N,Any}, i::NTuple{M,Any})
    if N < M
        return index_iterable(shape, ntuple(n -> i[n], Val{N}))
    elseif M < N && isa(last(i), Colon)
        return index_iterable(shape, ntuple(n -> (n > M ? Colon() : i[n]), Val{N}))
    else
        return Base.Iterators.product(map(colon2range, shape[1:M], i)...)
    end
end

Base.setindex!(t::TrackedArray, args...) = error("TrackedArrays do not support setindex!")

Base.IndexStyle(::TrackedArray) = IndexLinear()

Base.size(t::TrackedArray) = size(value(t))

Base.copy{T<:TrackedArray}(t::T) = t

Base.ones{V}(t::TrackedArray{V}) = ones(TrackedReal{V,Void}, size(t))

Base.zeros{V}(t::TrackedArray{V}) = zeros(TrackedReal{V,Void}, size(t))

reshape_body = :(TrackedArray(reshape(value(t), dims), dims), tape(t))
@eval Base.reshape{N}(t::TrackedArray, dims::Type{Val{N}}) = $reshape_body
@eval Base.reshape{N}(t::TrackedArray, dims::Tuple{Vararg{Int,N}}) = $reshape_body
@eval Base.reshape(t::TrackedArray, dims::Int64...) = $reshape_body
@eval Base.reshape(t::TrackedArray, dims::AbstractUnitRange...) = $reshape_body
@eval Base.reshape(t::TrackedArray, dims::Union{AbstractUnitRange,Int64}...) = $reshape_body

Base.hash(t::TrackedReal) = hash(value(t))
Base.hash(t::TrackedReal, hsh::UInt64) = hash(value(t), hsh)

Base.deepcopy{T<:TrackedReal}(t::T) = t
Base.copy{T<:TrackedReal}(t::T) = t

function Base.float{V,O}(t::TrackedReal{V,O})
    v = float(value(t))
    return TrackedReal{typeof(v),O}(v)
end

Base.float{V<:AbstractFloat}(t::TrackedReal{V}) = t

Base.one{V,O}(::Type{TrackedReal{V,O}}) = TrackedReal{V,O}(one(V))
Base.zero{V,O}(::Type{TrackedReal{V,O}}) = TrackedReal{V,O}(zero(V))

Base.rand{V,O}(::Type{TrackedReal{V,O}}) = TrackedReal{V,O}(rand(V))
Base.rand{V,O}(rng::AbstractRNG, ::Type{TrackedReal{V,O}}) = TrackedReal{V,O}(rand(rng, V))

Base.eps(t::TrackedReal) = eps(value(t))
Base.eps{T<:TrackedReal}(::Type{T}) = eps(valtype(T))

Base.floor(t::TrackedReal) = floor(value(t))
Base.floor{R<:Real}(::Type{R}, t::TrackedReal) = floor(R, value(t))

Base.ceil(t::TrackedReal) = ceil(value(t))
Base.ceil{R<:Real}(::Type{R}, t::TrackedReal) = ceil(R, value(t))

Base.trunc(t::TrackedReal) = trunc(value(t))
Base.trunc{R<:Real}(::Type{R}, t::TrackedReal) = trunc(R, value(t))

Base.round(t::TrackedReal) = round(value(t))
Base.round{R<:Real}(::Type{R}, t::TrackedReal) = round(R, value(t))

track(x::Real, tp::InstructionTape = InstructionTape()) = track(x, typeof(x), tp)

track(x::AbstractArray, tp::InstructionTape = InstructionTape()) = track(x, eltype(x), tp)

track{D}(x::Real, ::Type{D}, tp::InstructionTape = InstructionTape()) = TrackedReal(x, tp)

track{D}(x::AbstractArray, ::Type{D}, tp::InstructionTape = InstructionTape()) = TrackedArray(x, tp)

track!(t::TrackedArray, x::AbstractArray) = (value!(t, x); t)

track!(t::TrackedReal, x::Real) = (value!(t, x); t)

function track!{D}(t::AbstractArray{TrackedReal{D,Void}}, x::AbstractArray, tp::InstructionTape)
    for i in eachindex(t)
        t[i] = track(x[i], D, tp)
    end
    return t
end

idstr(x) = string(base(62, object_id(x)))[1:3]

function Base.show(io::IO, t::TrackedReal)
    tape_id = hastape(t) ? idstr(t.tape) : "---"
    origin_id = hasorigin(t) ? "$(t.index), $(idstr(t.origin))" : "---"
    id = idstr(t)
    print(io, "TrackedReal<$(id)>($(value(t)), $(tape_id), $(origin_id))")
end

function Base.show(io::IO, t::TrackedArray)
    print(t.value)
end

# function getindex(A::TrackedArray, I...)
#     Base.@_propagate_inbounds_meta
#     Base.error_if_canonical_indexing(Base.IndexStyle(A), A, I...)
#     out = Base._getindex(Base.IndexStyle(A), A, Base.to_indices(A, I)...)
#     cache = IntervalArithmetic.entireinterval()
#     tp = tape(A[1])
#     record!(tp, ScalarInstruction, getfield(Base, :getindex), A, out, cache)
#
# end

@inline Base.broadcast(f, X::TrackedArray) = TrackedArray(f.(X.value), X[1].tape)
@inline Base.broadcast(f, X::TrackedArray, Y::TrackedArray) = TrackedArray(f.(X.value, Y.value), X[1].tape)
@inline Base.broadcast(f, X::TrackedArray, y) = TrackedArray(f.(X.value, y), X[1].tape)
