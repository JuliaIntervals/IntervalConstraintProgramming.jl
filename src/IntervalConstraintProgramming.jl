__precompile__()

module IntervalConstraintProgramming

using   IntervalArithmetic,
        IntervalRootFinding,
        IntervalContractors

using ModelingToolkit
using MacroTools

import Base:
    show, ∩, ∪, !, ⊆, setdiff

import IntervalArithmetic: sqr, setindex

export
    BasicContractor,
    @contractor,
    Contractor,
    Separator, separator, @separator, @constraint,
    @function,
    SubPaving, Paving,
    pave, refine!,
    Vol,
    show_code

const reverse_operations = IntervalContractors.reverse_operations

include("ast.jl")
include("code_generation.jl")
include("contractor.jl")
include("separator.jl")
include("paving.jl")
include("setinversion.jl")
include("volume.jl")
include("functions.jl")

end # module
