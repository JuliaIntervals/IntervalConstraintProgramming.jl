abstract type AbstractInstruction end

const InstructionTape = Vector{AbstractInstruction}

function record!(tp::InstructionTape, ::Type{InstructionType}, args...) where InstructionType
    tp !== NULL_TAPE && push!(tp, InstructionType(args...))
    return nothing
end

function Base.:(==)(a::AbstractInstruction, b::AbstractInstruction)
    return (a.func == b.func &&
            a.input == b.input &&
            a.output == b.output &&
            a.cache == b.cache)
end

@inline capture(state) = state
@inline capture(state::Tuple) = map(capture, state)

struct ScalarInstruction{F,I,O,C} <: AbstractInstruction #Instruction struct to record every intermediate fundamental step
    func::F
    input::I
    output::O
    cache::C
    function ScalarInstruction{F,I,O,C}(func, input, output, cache) where {F,I,O,C}
        return new{F,I,O,C}(func, input, output, cache)
    end
end

@inline function _ScalarInstruction(func::F, input::I, output::O, cache::C) where {F,I,O,C}
    return ScalarInstruction{F,I,O,C}(func, input, output, cache)
end

function ScalarInstruction(func, input, output, cache = nothing)
    return _ScalarInstruction(func, capture(input), capture(output), cache)
end

function Base.show(io::IO, instruction::AbstractInstruction, pad = "")
    name = "ScalarInstruction"
    println(io, pad, "$(name)($(instruction.func)):")
    println(io, pad, "  input:  ", compactrepr(instruction.input))
    println(io, pad, "  output: ", compactrepr(instruction.output))
    print(io,   pad, "  cache:  ", compactrepr(instruction.cache))
end

# function Base.show(io::IO, tp::InstructionTape)
#     println("$(length(tp))-element InstructionTape:")
#     i = 1
#     for instruction in tp
#         print(io, "$i => ")
#         show(io, instruction)
#         println(io)
#         i += 1
#     end
# end

abstract type AbstractTape end

Base.show(io::IO, t::AbstractTape) = print(io, typeof(t).name, "(", t.func, ")")

struct Tape{F,I,O} <: AbstractTape #Tape type to hold the Instruction Tape
    func::F
    input::I
    output::O
    tape::InstructionTape
    # disable default outer constructor
    Tape{F,I,O}(func, input, output, tape) where {F,I,O} = new{F,I,O}(func, input, output, tape)
end

_Tape(func::F, input::I, output::O, tape::InstructionTape) where {F,I,O} = Tape{F,I,O}(func, input, output, tape)

compactrepr(x::Tuple) = "("*join(map(compactrepr, x), ",\n           ")*")"
# compactrepr(x::AbstractArray) = length(x) < 5 ? match(r"\[.*?\]", repr(x)).match : summary(x)
compactrepr(x) = repr(x)
