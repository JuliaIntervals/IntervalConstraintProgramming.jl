"""
    forward!(dag::SharedDAG, X::IntervalBox)

Forward propagation: set variable ranges from X, then evaluate all operation
nodes in topological order.
"""
function forward!(dag::SharedDAG, X::IntervalBox)
    for v in dag.variables
        v.range = X[v.index]
    end
    for node in dag.nodes
        if node isa OperationNode
            node.range = _eval_forward(node.op, node.children)
        end
    end
end

function _eval_forward(op::Function, children::Vector{AbstractNode})
    if length(children) == 1
        return op(children[1].range)
    elseif length(children) == 2
        return op(children[1].range, children[2].range)
    else
        return op([c.range for c in children]...)
    end
end

function _eval_forward(::typeof(^), children::Vector{AbstractNode})
    base = children[1].range
    exp_node = children[2]
    if exp_node isa ConstantNode
        n = exp_node.value
        if n == round(Int, n)
            return base ^ round(Int, n)
        end
    end
    return base ^ exp_node.range
end

"""
    backward!(dag::SharedDAG)

Backward propagation for all constraints. For each constraint entry, intersect
the root's range with the constraint, then propagate backward through the DAG.

When multiple constraints share nodes, each backward pass further narrows
shared variable and subexpression ranges.
"""
function backward!(dag::SharedDAG)
    for entry in dag.constraints
        entry.root.range = IntervalArithmetic.intersect_interval(entry.root.range, entry.constraint)
    end

    all_empty = all(isempty_interval(e.root.range) for e in dag.constraints)
    if all_empty
        for v in dag.variables
            v.range = emptyinterval()
        end
        return
    end

    for i in length(dag.nodes):-1:1
        node = dag.nodes[i]
        node isa OperationNode || continue
        _contract_backward!(node)
    end
end

"""
    backward!(dag::SharedDAG, constraint::Interval)

Backward propagation with a single override constraint applied to the first
(or only) root. Used by DAGContractor when contracting with a specific constraint.
"""
function backward!(dag::SharedDAG, constraint::Interval)
    entry = dag.constraints[1]
    entry.root.range = IntervalArithmetic.intersect_interval(entry.root.range, constraint)

    if isempty_interval(entry.root.range)
        for v in dag.variables
            v.range = emptyinterval()
        end
        return
    end

    for i in length(dag.nodes):-1:1
        node = dag.nodes[i]
        node isa OperationNode || continue
        _contract_backward!(node)
    end
end

function _contract_backward!(node::OperationNode)
    z = node.range
    children = node.children
    if isempty_interval(z)
        for c in children
            c.range = emptyinterval()
        end
        return
    end
    if length(children) == 1
        _contract_unary!(node.op, z, children[1])
    elseif length(children) == 2
        _contract_binary!(node.op, z, children[1], children[2])
    end
end

# --- Binary reverse contractors ---

function _contract_binary!(::typeof(+), z, left, right)
    _, l_new, r_new = plus_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(-), z, left, right)
    _, l_new, r_new = minus_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(*), z, left, right)
    _, l_new, r_new = mul_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(/), z, left, right)
    _, l_new, r_new = div_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(^), z, base_node, exp_node)
    if exp_node isa ConstantNode
        n = exp_node.value
        if n == round(Int, n)
            _, x_new, _ = power_rev(z, base_node.range, round(Int, n))
            base_node.range = IntervalArithmetic.intersect_interval(base_node.range, x_new)
            return
        end
    end
    _, x_new, y_new = power_rev(z, base_node.range, exp_node.range)
    base_node.range = IntervalArithmetic.intersect_interval(base_node.range, x_new)
    exp_node.range = IntervalArithmetic.intersect_interval(exp_node.range, y_new)
end

function _contract_binary!(::typeof(min), z, left, right)
    _, l_new, r_new = min_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(max), z, left, right)
    _, l_new, r_new = max_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

# --- Unary reverse contractors ---

for (jl_op, rev_fn) in [
    (:sin, :sin_rev), (:cos, :cos_rev), (:tan, :tan_rev),
    (:asin, :asin_rev), (:acos, :acos_rev), (:atan, :atan_rev),
    (:sinh, :sinh_rev), (:cosh, :cosh_rev), (:tanh, :tanh_rev),
    (:asinh, :asinh_rev), (:acosh, :acosh_rev), (:atanh, :atanh_rev),
    (:exp, :exp_rev), (:exp2, :exp2_rev), (:exp10, :exp10_rev),
    (:expm1, :expm1_rev),
    (:log, :log_rev), (:log2, :log2_rev), (:log10, :log10_rev),
    (:log1p, :log1p_rev),
    (:sqrt, :sqrt_rev), (:abs, :abs_rev), (:sign, :sign_rev),
]
    @eval function _contract_unary!(::typeof($jl_op), z, child)
        _, x_new = $rev_fn(z, child.range)
        child.range = IntervalArithmetic.intersect_interval(child.range, x_new)
    end
end

function _contract_unary!(::typeof(-), z, child)
    _, x_new = minus_rev(z, child.range)
    child.range = IntervalArithmetic.intersect_interval(child.range, x_new)
end

function _contract_unary!(op, z, child)
    @warn "No reverse contractor for unary $op — skipping" maxlog=1
end

function _contract_binary!(op, z, left, right)
    @warn "No reverse contractor for binary $op — skipping" maxlog=1
end

"""
    propagate!(dag::SharedDAG, X::IntervalBox; max_iter=10, tol=1e-10) → IntervalBox

Iterate forward-backward propagation on the DAG until convergence.
All constraints in the DAG are propagated each iteration, so narrowing
from one constraint benefits the others via shared variable nodes.
"""
function propagate!(dag::SharedDAG, X::IntervalBox; max_iter::Int=10, tol::Float64=1e-10)
    for _ in 1:max_iter
        old_ranges = IntervalBox(Tuple(v.range for v in dag.variables))
        forward!(dag, X)
        backward!(dag)
        X = IntervalBox(Tuple(v.range for v in dag.variables))
        isempty(X) && return X
        max_change = maximum(diam(old) - diam(new) for (old, new) in zip(old_ranges, X))
        max_change < tol && break
    end
    return X
end

"""
    propagate!(dag::SharedDAG, X::IntervalBox, constraint::Interval; ...) → IntervalBox

Propagate with a single override constraint (ignoring stored constraints).
Used by DAGContractor for boundary/complement contraction.
"""
function propagate!(dag::SharedDAG, X::IntervalBox, constraint::Interval;
                    max_iter::Int=10, tol::Float64=1e-10)
    for _ in 1:max_iter
        old_ranges = IntervalBox(Tuple(v.range for v in dag.variables))
        forward!(dag, X)
        backward!(dag, constraint)
        X = IntervalBox(Tuple(v.range for v in dag.variables))
        isempty(X) && return X
        max_change = maximum(diam(old) - diam(new) for (old, new) in zip(old_ranges, X))
        max_change < tol && break
    end
    return X
end
