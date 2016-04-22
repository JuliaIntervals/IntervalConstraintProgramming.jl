module ConstraintPropagation

export Domain, add_constraint, apply_contractor, initialize, @contractor, apply_all_contractors, @add_constraint

include("contractor.jl")
include("reverse_mode.jl")
include("domain.jl")


end # module
