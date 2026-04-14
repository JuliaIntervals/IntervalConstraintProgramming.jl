"""
    DAGContractor <: AbstractContractor

A contractor based on compiled DAG propagation (HC4Revise).
The DAG is built once, compiled into a flat instruction schedule, and
reused across all calls — no dynamic dispatch, no per-node allocation.

Constructor forms:
- `DAGContractor(expr, vars)` — builds and compiles its own DAG
- `DAGContractor(dag, expr, vars)` — adds to an existing SharedDAG and compiles
"""
struct DAGContractor{V} <: AbstractContractor
    vars::V
    dag::SharedDAG
    compiled::CompiledDAG
    ex::Any
end

function DAGContractor(ex::Num, vars::Vector{Num})
    dag = SharedDAG(vars)
    add_expression!(dag, ex, interval(0.0))
    cd = compile(dag)
    return DAGContractor(vars, dag, cd, ex)
end

function DAGContractor(dag::SharedDAG, ex::Num, vars::Vector{Num})
    add_expression!(dag, ex, interval(0.0))
    cd = compile(dag)
    return DAGContractor(vars, dag, cd, ex)
end

function (C::DAGContractor)(X::IntervalBox, constraint::Interval=interval(0.0))
    return propagate!(C.compiled, X, constraint)
end

"""
    DAGSeparator <: AbstractSeparator

A separator that uses compiled DAG-based propagation.
Drop-in replacement for `Separator`.

Constructor forms:
- `DAGSeparator(expr, vars, constraint)` — builds and compiles its own DAG
- `DAGSeparator(dag, expr, vars, constraint)` — uses an existing SharedDAG
- `DAGSeparator(symbolic_inequality, vars)` — parses the inequality
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

function DAGSeparator(dag::SharedDAG, expr::Num, vars::Vector{Num}, constraint::Interval)
    contractor = DAGContractor(dag, expr, vars)
    f = make_function(expr, vars)
    return DAGSeparator(vars, expr, constraint, f, contractor)
end

function (SS::DAGSeparator)(X)
    if any(x -> isinf(diam(x)), X)
        return _separate_infinite_dag(SS, X)
    end

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
        outer = C(X, interval(-Inf, a)) ⊔ C(X, interval(b, Inf))
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
