"""
    forward!(dag::ConstraintDAG, X::IntervalBox)

Forward propagation: evaluate intervals from leaves to root in topological order.
Sets `range` on every node.
"""
function forward!(dag::ConstraintDAG, X::IntervalBox)
    for v in dag.variables
        v.range = X[v.index]
    end

    for node in dag.nodes
        if node isa OperationNode
            node.range = _eval_forward(node.op, node.children)
        end
        # VariableNode and ConstantNode ranges are already set
    end

    return dag.root.range
end

function _eval_forward(op::Function, children::Vector{AbstractNode})
    if length(children) == 1
        return op(children[1].range)
    elseif length(children) == 2
        return op(children[1].range, children[2].range)
    else
        # Shouldn't happen after n-ary decomposition, but handle gracefully
        return op([c.range for c in children]...)
    end
end

# Special case: ^ with integer exponent. Symbolics stores ^(x, 2) where
# the second arg is a ConstantNode. IntervalArithmetic dispatches x^n.
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
    backward!(dag::ConstraintDAG)

Backward propagation: propagate constraint from root to leaves in reverse
topological order using reverse interval contractors.

The root's range is first intersected with the constraint. Then each
OperationNode propagates narrowed ranges to its children.
"""
function backward!(dag::ConstraintDAG)
    dag.root.range = IntervalArithmetic.intersect_interval(dag.root.range, dag.constraint)

    if isempty_interval(dag.root.range)
        # Constraint is infeasible on this box — mark everything empty
        for v in dag.variables
            v.range = emptyinterval()
        end
        return
    end

    # Traverse in reverse topological order (root → leaves)
    for i in length(dag.nodes):-1:1
        node = dag.nodes[i]
        node isa OperationNode || continue
        _contract_backward!(node)
    end
end

"""
Apply the reverse contractor for a single operation node, narrowing
both `node.range` and each child's range in place.
"""
function _contract_backward!(node::OperationNode)
    op = node.op
    children = node.children
    z = node.range

    if isempty_interval(z)
        for c in children
            c.range = emptyinterval()
        end
        return
    end

    if length(children) == 1
        _contract_unary!(op, z, children[1])
    elseif length(children) == 2
        _contract_binary!(op, z, children[1], children[2])
    end
end

# --- Binary reverse contractors ---

function _contract_binary!(::typeof(+), z, left, right)
    z_new, l_new, r_new = plus_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(-), z, left, right)
    z_new, l_new, r_new = minus_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(*), z, left, right)
    z_new, l_new, r_new = mul_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(/), z, left, right)
    z_new, l_new, r_new = div_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(^), z, base_node, exp_node)
    if exp_node isa ConstantNode
        n = exp_node.value
        if n == round(Int, n)
            # power_rev(z, x, n::Integer) → (z', x', n)
            z_new, x_new, _ = power_rev(z, base_node.range, round(Int, n))
            base_node.range = IntervalArithmetic.intersect_interval(base_node.range, x_new)
            return
        end
    end
    # General case: x^y
    z_new, x_new, y_new = power_rev(z, base_node.range, exp_node.range)
    base_node.range = IntervalArithmetic.intersect_interval(base_node.range, x_new)
    exp_node.range = IntervalArithmetic.intersect_interval(exp_node.range, y_new)
end

function _contract_binary!(::typeof(min), z, left, right)
    z_new, l_new, r_new = min_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

function _contract_binary!(::typeof(max), z, left, right)
    z_new, l_new, r_new = max_rev(z, left.range, right.range)
    left.range = IntervalArithmetic.intersect_interval(left.range, l_new)
    right.range = IntervalArithmetic.intersect_interval(right.range, r_new)
end

# --- Unary reverse contractors ---

for (jl_op, rev_fn) in [
    (:sin, :sin_rev),
    (:cos, :cos_rev),
    (:tan, :tan_rev),
    (:asin, :asin_rev),
    (:acos, :acos_rev),
    (:atan, :atan_rev),
    (:sinh, :sinh_rev),
    (:cosh, :cosh_rev),
    (:tanh, :tanh_rev),
    (:asinh, :asinh_rev),
    (:acosh, :acosh_rev),
    (:atanh, :atanh_rev),
    (:exp, :exp_rev),
    (:exp2, :exp2_rev),
    (:exp10, :exp10_rev),
    (:expm1, :expm1_rev),
    (:log, :log_rev),
    (:log2, :log2_rev),
    (:log10, :log10_rev),
    (:log1p, :log1p_rev),
    (:sqrt, :sqrt_rev),
    (:abs, :abs_rev),
    (:sign, :sign_rev),
]
    @eval function _contract_unary!(::typeof($jl_op), z, child)
        z_new, x_new = $rev_fn(z, child.range)
        child.range = IntervalArithmetic.intersect_interval(child.range, x_new)
    end
end

# Unary minus: -(x)
function _contract_unary!(::typeof(-), z, child)
    z_new, x_new = minus_rev(z, child.range)
    child.range = IntervalArithmetic.intersect_interval(child.range, x_new)
end

# Fallback for unknown operations — no contraction, just leave ranges as-is
function _contract_unary!(op, z, child)
    @warn "No reverse contractor for unary $op — skipping" maxlog=1
end

function _contract_binary!(op, z, left, right)
    @warn "No reverse contractor for binary $op — skipping" maxlog=1
end


"""
    propagate!(dag::ConstraintDAG, X::IntervalBox; max_iter=10, tol=1e-10) → IntervalBox

Iterate forward-backward propagation on the DAG until convergence or `max_iter`
iterations. Returns the narrowed IntervalBox.

This implements the HC4Revise algorithm: each iteration does one forward pass
(natural interval evaluation) followed by one backward pass (constraint narrowing).
For expressions where a variable appears multiple times, a single pass cannot
fully propagate — iteration is needed because each pass tightens the shared node,
which then feeds tighter bounds into the next forward evaluation.
"""
function propagate!(dag::ConstraintDAG, X::IntervalBox; max_iter::Int=10, tol::Float64=1e-10)
    for _ in 1:max_iter
        old_ranges = IntervalBox(Tuple(v.range for v in dag.variables))

        forward!(dag, X)
        backward!(dag)

        # Build new X from narrowed variable ranges
        X = IntervalBox(Tuple(v.range for v in dag.variables))

        if isempty(X)
            return X
        end

        # Check convergence: did the variable ranges change significantly?
        max_change = maximum(
            diam(old) - diam(new)
            for (old, new) in zip(old_ranges, X)
        )
        if max_change < tol
            break
        end
    end

    return X
end
