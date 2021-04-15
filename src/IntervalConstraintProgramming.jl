__precompile__()

module IntervalConstraintProgramming

using   IntervalArithmetic,
        IntervalContractors

using Symbolics
using Symbolics: operation, value, arguments, toexpr

using Symbolics: @register

using ReversePropagation

# using MacroTools

import Base:
    show, ∩, ∪, !, ⊆, setdiff, symdiff, &, |

import IntervalArithmetic: sqr, setindex


@register ¬(x)
@register x & y
@register x | y

export
    # BasicContractor,
    # @contractor,
    Contractor,
    Separator, #, separator, @separator, @constraint,
    #@function,
    #SubPaving, Paving,
    pave #, refine!,
    # Vol,
    # show_code

export ¬

const reverse_operations = IntervalContractors.reverse_operations

# include("ast.jl")
# include("code_generation.jl")
# include("contractor.jl")
# include("separator.jl")
# include("paving.jl")
# include("setinversion.jl")
# include("volume.jl")
# include("functions.jl")


include("utils.jl")
include("new_contractor.jl")
include("new_pave.jl")
include("set_operations.jl")


end # module
