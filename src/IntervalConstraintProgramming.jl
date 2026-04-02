__precompile__()

module IntervalConstraintProgramming

using IntervalArithmetic, IntervalArithmetic.Symbols
using IntervalContractors
using IntervalBoxes

using Symbolics
using Symbolics: operation, value, arguments, toexpr, Sym

using Symbolics: @register_symbolic

using StaticArrays

using ReversePropagation

# using MacroTools

import IntervalArithmetic.Symbols: ⊓, ⊔

import Base:
    show, !, ⊆, setdiff, symdiff, &, |, ∈

import IntervalArithmetic: mid, interval, emptyinterval, isinf, isinterior, hull, mince

@register_symbolic ¬(x)
@register_symbolic x ∨ y
@register_symbolic x ∧ y

# We cannot register `x ∈ y::Interval` as a symbolic operation because
# SymbolicUtils hash-consing requires isequal/hash, which Interval deliberately
# does not define (IEEE 1788). Instead, decompose into comparisons that the
# package already handles.
Base.in(x::Num, y::Interval) = (x >= Num(inf(y))) & (x <= Num(sup(y)))

export
    # BasicContractor,
    # @contractor,
    Contractor,
    Separator, #, separator, @separator, @constraint,
    #@function,
    #SubPaving, Paving,
    pave, #, refine!,
    # Vol,
    # show_code
    separator, constraint,
    Model,
    @constraint, 
    add_constraint!, 
    variables, 
    add_variables!,
    ConstraintProblem

export ¬

const reverse_operations = IntervalContractors.reverse_operations


include("utils.jl")
include("contractor.jl")
include("set_operations.jl")
include("pave.jl")


end # module
