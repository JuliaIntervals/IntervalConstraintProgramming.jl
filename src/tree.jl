# Represent a sub-paving as a binary tree

@enum STATUS inside outside boundary


immutable Tree{T}
    data::Vector{T}
    children::Vector{Vector{Int}}
    parent::Vector{Int}
end

Tree{T}(::Type{T}) = Tree(T[], Vector{Int}[], Int[])

Tree{T}(node::T) = Tree([node], [Int[]], [-1])  # -1 since no parent


function add_child!{T}(tree::Tree{T}, parent::Int, child::T)
    # add node:
    push!(tree.data, child)
    push!(tree.parent, parent)
    push!(tree.children, Int[])

    which = length(tree.data)
    push!(tree.children[parent], which)
    return which
end

using ValidatedNumerics, IntervalConstraintProgramming
immutable Separation{N,T}
    inner::IntervalBox{N,T}
    outer::IntervalBox{N,T}
end

#Separation(S::Separator, IntervalBox{N,T})

function newpave{N,T}(S::Separator, X::IntervalBox{N,T}, ϵ=0.1)

    separation = Separation(S(X)...)

    tree = Tree(separation)
    working = [1]

    # @show tree

    # @assert length(tree.data) == length(tree.parent) == length(tree.children)

    while !isempty(working)

        parent = pop!(working)
        separation = tree.data[parent]

        # @show separation


        if isempty(separation.inner) || isempty(separation.outer)
            continue
        end

        boundary = separation.inner ∩ separation.outer

        if diam(boundary) < ϵ || isempty(boundary)
            continue
        end

        separation = Separation(S(X)...)


        X1, X2 = IntervalConstraintProgramming.bisect(boundary)

        child1 = add_child!(tree, parent, Separation(S(X1)...))
        child2 = add_child!(tree, parent, Separation(S(X2)...))

        push!(working, child1, child2)

    end

    return tree

end
