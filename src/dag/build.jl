const SU = Symbolics.SymbolicUtils

"""
    build_dag(expr::Num, vars::Vector{Num}, constraint::Interval) → ConstraintDAG

Build a DAG from a Symbolics expression. Uses a cache dictionary for
common subexpression elimination (CSE): identical symbolic subexpressions
map to the same node.

N-ary `+` and `*` are decomposed into left-associated binary operations
so that each node has exactly 2 children for binary ops (or 1 for unary).
"""
function build_dag(expr::Num, variables::Vector{Num}, constraint::Interval)
    unwrapped_vars = Symbolics.value.(variables)
    sym_expr = Symbolics.value(expr)

    # Map variable symbols to VariableNodes
    var_nodes = VariableNode[]
    var_map = Dict{Any, VariableNode}()
    for (i, v) in enumerate(unwrapped_vars)
        vn = VariableNode(Symbolics.nameof(v), i, entireinterval())
        push!(var_nodes, vn)
        var_map[v] = vn
    end

    # Cache for CSE: symbolic subexpr → AbstractNode
    cache = Dict{UInt, AbstractNode}()
    all_nodes = AbstractNode[]

    root = _build_node!(sym_expr, var_map, cache, all_nodes)

    return ConstraintDAG(var_nodes, all_nodes, root, constraint)
end

"""
Recursively build DAG nodes from a symbolic expression.
Returns the node corresponding to `expr`.
"""
function _build_node!(expr, var_map, cache, all_nodes)
    # Check cache first (CSE)
    h = objectid(expr)
    haskey(cache, h) && return cache[h]

    node = if haskey(var_map, expr)
        # It's a known variable
        vn = var_map[expr]
        if vn ∉ all_nodes
            push!(all_nodes, vn)
        end
        vn

    elseif Symbolics.issym(expr)
        # Unknown symbol — shouldn't happen if vars are correctly specified
        error("Unknown variable in expression: $(Symbolics.nameof(expr))")

    elseif SU.iscall(expr)
        _build_operation!(expr, var_map, cache, all_nodes)

    else
        # Literal number
        val = Symbolics.value(expr)
        cn = ConstantNode(val)
        push!(all_nodes, cn)
        cn
    end

    cache[h] = node
    return node
end

"""
Build an OperationNode from a symbolic function call.
Handles n-ary `+` and `*` by decomposing to left-associated binary chains.
"""
function _build_operation!(expr, var_map, cache, all_nodes)
    op = Symbolics.operation(expr)
    args = Symbolics.arguments(expr)

    if (op === (+) || op === (*)) && length(args) > 2
        # Decompose n-ary to binary: (((a + b) + c) + d)
        node = _build_node!(args[1], var_map, cache, all_nodes)
        for i in 2:length(args)
            right = _build_node!(args[i], var_map, cache, all_nodes)
            parent = OperationNode(op, AbstractNode[node, right])
            push!(all_nodes, parent)
            node = parent
        end
        return node
    end

    # Standard case: unary or binary operation
    child_nodes = AbstractNode[
        _build_node!(a, var_map, cache, all_nodes) for a in args
    ]

    node = OperationNode(op, child_nodes)
    push!(all_nodes, node)
    return node
end
