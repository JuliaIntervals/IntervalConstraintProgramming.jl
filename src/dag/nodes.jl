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

# Convenience accessors

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
    ConstraintDAG

Directed acyclic graph representing an expression with a constraint on its output.

- `variables`: input variable nodes (ordered to match IntervalBox)
- `nodes`: all nodes in topological order (leaves first, root last)
- `root`: the output node
- `constraint`: interval the root must lie in
"""
struct ConstraintDAG
    variables::Vector{VariableNode}
    nodes::Vector{AbstractNode}     # topological order
    root::AbstractNode
    constraint::Interval
end

function Base.show(io::IO, dag::ConstraintDAG)
    vars = join([string(v.name) for v in dag.variables], ", ")
    print(io, "ConstraintDAG($(length(dag.nodes)) nodes, vars=($vars), constraint=$(dag.constraint))")
end
