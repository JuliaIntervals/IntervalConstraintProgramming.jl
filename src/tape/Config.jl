# Framework to initialize the tracked input array and the Tape of Instructions
abstract type AbstractConfig end

immutable Config{I} <: AbstractConfig
    input::I
    tape::InstructionTape
    (::Type{Config{I}}){I}(input, tape) = new{I}(input, tape)
end

Base.show(io::IO, cfg::AbstractConfig) = print(io, typeof(cfg).name)

Config{T}(input::AbstractArray{T}, tp::InstructionTape = InstructionTape()) = Config(input, T, tp)

_Config{I}(input::I, tape::InstructionTape) = Config{I}(input, tape)

function Config{D}(input::AbstractArray, ::Type{D}, tp::InstructionTape = InstructionTape())
    return _Config(track(similar(input), D, tp), tp)
end
