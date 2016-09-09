#__precompile__(true)

module IntervalConstraintProgramming

using ValidatedNumerics
using MacroTools
using Compat
using FixedSizeArrays: setindex

import Base:
    show, ∩, ∪, !, ⊆, setdiff

export
    @contractor,
    Separator, separator, @separator, @constraint,
    @function,
    SubPaving, Paving,
    pave, refine!,
    Vol,
    show_code


include("reverse_mode.jl")
include("contractor.jl")
include("separator.jl")
include("paving.jl")
include("setinversion.jl")
include("volume.jl")
include("functions.jl")
include("ast.jl")


end # module
