__precompile__(true)

module ConstraintPropagation

using ValidatedNumerics
using MacroTools
using Compat




export
    Domain, add_constraint, apply_contractor, initialize, @contractor, apply_all_contractors, @constraint,
    separator, @separator,
    set_inversion


include("reverse_mode.jl")
include("contractor.jl")
include("separator.jl")
# include("domain.jl")
include("set_inversion.jl")


end # module
