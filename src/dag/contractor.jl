"""
    DAGContractor <: AbstractContractor

A contractor based on explicit DAG propagation (HC4Revise).
Alternative to the code-generation approach in `Contractor`.

Stores the expression and variables so it can build a DAG with any constraint
at call time. By default contracts onto `f(x) = 0` (the boundary), matching
the behavior of the code-generation `Contractor`.
"""
struct DAGContractor{V} <: AbstractContractor
    vars::V
    ex::Any
end

DAGContractor(ex::Num, vars::Vector{Num}) = DAGContractor(vars, ex)

function (C::DAGContractor)(X::IntervalBox, constraint::Interval=interval(0.0))
    dag = build_dag(C.ex, C.vars, constraint)
    return propagate!(dag, X)
end

"""
    DAGSeparator <: AbstractSeparator

A separator that uses DAG-based propagation.
Drop-in replacement for `Separator` — same `(boundary, inner, outer)` output.
"""
struct DAGSeparator{V, E, C, F} <: AbstractSeparator
    vars::V
    ex::E
    constraint::C
    f::F
    contractor::DAGContractor
end

function DAGSeparator(expr::Num, vars::Vector{Num}, constraint::Interval)
    contractor = DAGContractor(expr, vars)
    f = make_function(expr, vars)
    return DAGSeparator(vars, expr, constraint, f, contractor)
end

function (SS::DAGSeparator)(X)
    if any(x -> isinf(diam(x)), X)
        return _separate_infinite_dag(SS, X)
    end

    # Contract onto the boundary (f(x) = 0), same as original Separator
    boundary = SS.contractor(X)

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

function _separate_infinite_dag(SS::DAGSeparator, X::IntervalBox)
    C = SS.contractor
    a, b = inf(SS.constraint), sup(SS.constraint)

    inner = C(X, interval(a, b))

    local outer
    if a == -Inf
        outer = C(X, interval(b, Inf))
    elseif b == Inf
        outer = C(X, interval(-Inf, a))
    else
        outer1 = C(X, interval(-Inf, a))
        outer2 = C(X, interval(b, Inf))
        outer = outer1 ⊔ outer2
    end

    boundary = inner ⊓ outer
    return (boundary, inner, outer)
end

"""
    DAGSeparator(orig_expr, vars)

Build a DAG-based separator from a symbolic constraint expression,
handling boolean combinations (`&`, `|`, `!`) by composing separators.
"""
function DAGSeparator(orig_expr, vars)
    ex_val = Symbolics.value(orig_expr)

    if SU.iscall(ex_val)
        op = Symbolics.operation(ex_val)
        args = Symbolics.arguments(ex_val)

        if op === (&)
            return DAGSeparator(Num(args[1]), vars) ⊓ DAGSeparator(Num(args[2]), vars)
        elseif op === (|)
            return DAGSeparator(Num(args[1]), vars) ⊔ DAGSeparator(Num(args[2]), vars)
        elseif op === (!)
            return ¬(DAGSeparator(Num(args[1]), vars))
        end
    end

    ex, constraint = analyse(orig_expr)
    return DAGSeparator(ex, vars, constraint)
end
