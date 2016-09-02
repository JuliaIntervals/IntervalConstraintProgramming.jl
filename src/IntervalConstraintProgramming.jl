__precompile__(true)

module IntervalConstraintProgramming

using ValidatedNumerics
using MacroTools
using Compat
using FixedSizeArrays: setindex

import Base:
    show

export
    @contractor,
    Separator, separator, @separator, @constraint,
    SubPaving, Paving,
    setinverse, refine!,
    Vol,
    show_code


include("reverse_mode.jl")
include("contractor.jl")
include("separator.jl")
include("paving.jl")
include("setinversion.jl")
include("volume.jl")


end # module
