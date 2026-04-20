abstract type AbstractContractor end


"""
	Contractor(ex, vars)
	Contractor(ssa::SSAFunction, ex, vars)

HC4Revise forward--backward contractor for the constraint `ex(vars...) ∈ constraint`.

The symbolic expression is first lowered to SSA form via
`ReversePropagation.cse_equations`; the resulting `SSAFunction` is stored on the
contractor so it can be reused (e.g. shared between a `Separator` and other
contractors over the same expression).
"""
struct Contractor{V, E, S, CC} <: AbstractContractor
    vars::V
    ex::E
    ssa::S
    contractor::CC
end

Contractor(ex, vars) = Contractor(cse_equations(ex), ex, vars)

Contractor(ssa::SSAFunction, ex, vars) =
    Contractor(vars, ex, ssa, forward_backward_contractor(ssa, vars))

(CC::Contractor)(X, constraint=interval(0.0)) = IntervalBox(CC.contractor(X, constraint)[1])


abstract type AbstractSeparator end

"A separator models the inside and outside of a constraint set using a forward--backward contractor"
struct Separator{V,E,C,F,R} <: AbstractSeparator
    vars::V
    ex::E
    constraint::C
    f::F
    contractor::R
end

# Base.show(io::IO, S::Separator) = print(io, "Separator($(S.ex) ∈ $(S.constraint), vars = $(join(S.vars, ", ")))")

function Base.show(io::IO, S::AbstractSeparator)
    if hasproperty(S, :constraint)
        print(io, "Separator($(S.ex) ∈ $(S.constraint), vars=$(join(S.vars, ", ")))")
    else
        print(io, "Separator($(S.ex), vars=$(join(S.vars, ", ")))")
    end
end

function Separator(orig_expr, vars)
    ex, constraint = analyse(orig_expr)

    return Separator(ex, vars, constraint)
end

function Separator(ex, vars, constraint::Interval)
    ssa = cse_equations(ex)
    return Separator(vars, ex, constraint, make_function(ex, vars), Contractor(ssa, ex, vars))
end

function separate_infinite_box(S::Separator, X::IntervalBox)
    # for an box that extends to infinity we cannot evaluate at a corner
    # so use the old method instead where we do inner and outer contractors separately

    C = S.contractor
    a, b = inf(S.constraint), sup(S.constraint)

    inner = C(X, interval(a, b))

    # to compute outer, we contract with respect to the complement of `a..b`:
    local outer
    if a == -Inf
        outer = C(X, interval(b, Inf))

    elseif b == Inf
        outer = C(X, interval(-Inf, a))

    else
        # the complement is a union of two pieces
        outer1 = C(X, interval(-Inf, a))
        outer2 = C(X, interval(b, Inf))

        outer = outer1 ⊔ outer2
    end

    boundary = inner ⊓ outer

    return (boundary, inner, outer)
end


"Returns boundary, inner, outer"
function (SS::Separator)(X)

    if any(x -> isinf(diam(x)), X)
        return separate_infinite_box(SS, X)
    end

    # using the contractor to compute the boundary:
    boundary = SS.contractor(X)  # contract with respect to 0, which is always the boundary

    # extend the boundary by evaluating at corners of the box to determine inner and outer:

    lb = IntervalBox(inf.(X))
    ub = IntervalBox(sup.(X))

    inner = boundary
    outer = boundary

    lb_image = SS.f(lb)
    if !isempty_interval(lb_image) && issubset_interval(lb_image, SS.constraint)
        inner = inner ⊔ lb
    else
        outer = outer ⊔ lb
    end

    ub_image = SS.f(ub)
    if !isempty_interval(ub_image) && issubset_interval(ub_image, SS.constraint)
        inner = inner ⊔ ub
    else
        outer = outer ⊔ ub
    end

    return boundary, inner, outer
end
