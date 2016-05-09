__precompile__(true)

module ConstraintPropagation

using ValidatedNumerics
using MacroTools
using Compat

export
    Domain, add_constraint, apply_contractor, initialize, @contractor, apply_all_contractors, @constraint


include("reverse_mode.jl")
include("contractor.jl")
include("domain.jl")


end # module
