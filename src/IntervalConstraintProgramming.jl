__precompile__(true)

module IntervalConstraintProgramming

using ValidatedNumerics
using MacroTools
using Compat

export
    @contractor,
    Separator, separator, @separator, @constraint,
    setinverse,
    vol 


include("reverse_mode.jl")
include("contractor.jl")
include("separator.jl")
include("setinversion.jl")
include("volume.jl")


end # module
