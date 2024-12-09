abstract type AbstractContractor end


struct Contractor{V, E, CC} <: AbstractContractor
    vars::V
    ex::E
    contractor::CC
end

Contractor(ex, vars) = Contractor(vars, ex, forward_backward_contractor(ex, vars))

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

Base.show(io::IO, S::AbstractSeparator) = print(io, "Separator($(S.ex), vars=$(join(S.vars, ", ")))")

function Separator(orig_expr, vars)
    ex, constraint = analyse(orig_expr)

    return Separator(ex, vars, constraint)
end

Separator(ex, vars, constraint::Interval) = Separator(vars, ex ∈ constraint, constraint, make_function(ex, vars), Contractor(ex, vars))

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
