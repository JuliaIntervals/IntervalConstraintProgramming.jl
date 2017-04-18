__precompile__()

module IntervalConstraintProgramming

using IntervalArithmetic, IntervalRootFinding

using MacroTools

import Base:
    show, ∩, ∪, !, ⊆, setdiff

import IntervalArithmetic: sqr, setindex

export
    @contractor,
    Separator, separator, @separator, @constraint,
    @function,
    SubPaving, Paving,
    pave, refine!,
    Vol,
    show_code


include("reverse_mode.jl")
include("ast.jl")
include("code_generation.jl")
include("contractor.jl")
include("separator.jl")
include("paving.jl")
include("setinversion.jl")
include("volume.jl")
include("functions.jl")

end # module
