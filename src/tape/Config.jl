# Framework to initialize the tracked input array and the Tape of Instructions
abstract type AbstractConfig end

struct Config{I} <: AbstractConfig
    input::I
    tape::InstructionTape
    Config{I}(input, tape) where {I} = new{I}(input, tape)
end

Base.show(io::IO, cfg::AbstractConfig) = print(io, typeof(cfg).name)

Config(input::AbstractArray{T}, tp::InstructionTape = InstructionTape()) where {T} = Config(input, T, tp)

_Config(input::I, tape::InstructionTape) where {I} = Config{I}(input, tape)

function Config(input::AbstractArray, ::Type{D}, tp::InstructionTape = InstructionTape()) where D
    return _Config(track(similar(input), D, tp), tp)
end
