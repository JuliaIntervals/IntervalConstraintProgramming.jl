__precompile__()

module IntervalConstraintProgramming

using   IntervalArithmetic,
        IntervalRootFinding,
        IntervalContractors

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
    show_code,
    icp, icp!

const reverse_operations = IntervalContractors.reverse_operations
const ARRAY_TYPES = (:AbstractArray, :AbstractVector, :AbstractMatrix, :Array, :Vector, :Matrix)
const REAL_TYPES = (:Bool, :Integer, :(Irrational{:e}), :(Irrational{:π}), :Rational, :BigFloat, :BigInt, :AbstractFloat, :Real)
const FUNCTIONS = ((:Base, :+, 2), (:Base, :/, 2), (:Base, :^, 2), (:Base, :asin, 1), (:Base, :cos, 1), (:Base, :exp, 1), (:Base, :*, 2), (:Base, :abs, 1), (:Base, :log, 1), (:Base, :-, 2), (:Base, :sqrt, 1), (:Base, :tan, 1), (:Base, :sin, 1), )

include("ast.jl")
include("code_generation.jl")
include("contractor.jl")
include("separator.jl")
include("paving.jl")
include("setinversion.jl")
include("volume.jl")
include("functions.jl")

include("tape/tape.jl")
include("tape/Config.jl")
include("tape/tracked.jl")
include("tape/operations.jl")
include("tape/icp.jl")

end # module
