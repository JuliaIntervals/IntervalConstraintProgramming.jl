const SU = Symbolics.SymbolicUtils

"""
    add_expression!(dag::SharedDAG, expr::Num, constraint::Interval) → ConstraintEntry

Add an expression with its constraint to an existing SharedDAG. Reuses
variable nodes and any common subexpressions already in the DAG.

Returns the ConstraintEntry that was added.
"""
function add_expression!(dag::SharedDAG, expr::Num, constraint::Interval)
    sym_expr = Symbolics.value(expr)
    root = _build_node!(sym_expr, dag)
    entry = ConstraintEntry(root, constraint)
    push!(dag.constraints, entry)
    return entry
end

"""
    build_dag(expr::Num, vars::Vector{Num}, constraint::Interval) → SharedDAG

Convenience: build a SharedDAG with a single expression and constraint.
"""
function build_dag(expr::Num, vars::Vector{Num}, constraint::Interval)
    dag = SharedDAG(vars)
    add_expression!(dag, expr, constraint)
    return dag
end

"""
Recursively build DAG nodes from a symbolic expression, reusing existing
nodes in the SharedDAG via the node_cache (CSE).
"""
function _build_node!(expr, dag::SharedDAG)
    h = objectid(expr)
    haskey(dag.node_cache, h) && return dag.node_cache[h]

    node = if Symbolics.issym(expr)
        name = Symbolics.nameof(expr)
        if haskey(dag.var_map, name)
            dag.var_map[name]
        else
            error("Unknown variable in expression: $name")
        end

    elseif SU.iscall(expr)
        _build_operation!(expr, dag)

    else
        # Literal number
        val = Symbolics.value(expr)
        cn = ConstantNode(val)
        push!(dag.nodes, cn)
        cn
    end

    dag.node_cache[h] = node
    return node
end

"""
Build an OperationNode, decomposing n-ary `+` and `*` into binary chains.
"""
function _build_operation!(expr, dag::SharedDAG)
    op = Symbolics.operation(expr)
    args = Symbolics.arguments(expr)

    if (op === (+) || op === (*)) && length(args) > 2
        node = _build_node!(args[1], dag)
        for i in 2:length(args)
            right = _build_node!(args[i], dag)
            parent = OperationNode(op, AbstractNode[node, right])
            push!(dag.nodes, parent)
            node = parent
        end
        return node
    end

    child_nodes = AbstractNode[_build_node!(a, dag) for a in args]
    node = OperationNode(op, child_nodes)
    push!(dag.nodes, node)
    return node
end
