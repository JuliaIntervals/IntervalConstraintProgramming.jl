__precompile__(true)

module ConstraintProgramming

using ValidatedNumerics
using MacroTools
using Compat




export
    @contractor,
    Separator, separator, @separator, @constraint,
    setinverse


include("reverse_mode.jl")
include("contractor.jl")
include("separator.jl")
include("setinversion.jl")


end # module
