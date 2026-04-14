abstract type AbstractNode end

mutable struct VariableNode <: AbstractNode
    name::Symbol
    index::Int          # position in the input IntervalBox
    range::Interval     # current interval bound
end

mutable struct ConstantNode <: AbstractNode
    value::Float64
    range::Interval     # [value, value], set once
end

ConstantNode(v::Real) = ConstantNode(Float64(v), interval(Float64(v)))

mutable struct OperationNode <: AbstractNode
    op::Function            # +, *, sin, ^, etc.
    children::Vector{AbstractNode}
    range::Interval         # current interval bound (set during forward pass)
end

OperationNode(op, children) = OperationNode(op, children, entireinterval())

is_variable(n::VariableNode) = true
is_variable(::AbstractNode) = false

is_constant(n::ConstantNode) = true
is_constant(::AbstractNode) = false

is_operation(n::OperationNode) = true
is_operation(::AbstractNode) = false

function Base.show(io::IO, n::VariableNode)
    print(io, "Var($(n.name), $(n.range))")
end

function Base.show(io::IO, n::ConstantNode)
    print(io, "Const($(n.value))")
end

function Base.show(io::IO, n::OperationNode)
    print(io, "Op($(n.op), $(length(n.children)) children, $(n.range))")
end

"""
A root-constraint pair: an expression root node together with the interval
constraint that its output must satisfy.
"""
struct ConstraintEntry
    root::AbstractNode
    constraint::Interval
end

"""
    SharedDAG

A persistent DAG that can hold multiple expressions sharing variable nodes
and common subexpressions. Each expression is registered as a `ConstraintEntry`
(root node + constraint interval).

Built incrementally via `add_expression!`. The `nodes` vector is kept in
topological order (leaves first), so forward propagation is a single pass
and backward propagation is the reverse.
"""
mutable struct SharedDAG
    variables::Vector{VariableNode}
    nodes::Vector{AbstractNode}         # topological order
    constraints::Vector{ConstraintEntry}
    var_map::Dict{Symbol, VariableNode}
    node_cache::Dict{UInt, AbstractNode}
end

function SharedDAG(variables::Vector{Num})
    unwrapped = Symbolics.value.(variables)
    var_nodes = VariableNode[]
    var_map = Dict{Symbol, VariableNode}()
    all_nodes = AbstractNode[]

    for (i, v) in enumerate(unwrapped)
        name = Symbolics.nameof(v)
        vn = VariableNode(name, i, entireinterval())
        push!(var_nodes, vn)
        push!(all_nodes, vn)
        var_map[name] = vn
    end

    return SharedDAG(var_nodes, all_nodes, ConstraintEntry[], var_map, Dict{UInt, AbstractNode}())
end

function Base.show(io::IO, dag::SharedDAG)
    vars = join([string(v.name) for v in dag.variables], ", ")
    nc = length(dag.constraints)
    print(io, "SharedDAG($(length(dag.nodes)) nodes, vars=($vars), $nc constraints)")
end
