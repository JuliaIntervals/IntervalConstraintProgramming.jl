module ConstraintPropagation

export Domain, add_constraint, apply_contractor, initialize, @contractor, apply_all_contractors

include("contractor.jl")
include("reverse_mode.jl")
include("domain.jl")


end # module
