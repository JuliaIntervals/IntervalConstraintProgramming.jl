# Represent a sub-paving as a binary tree

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



function traverse!{N,T}(tree::Tree{Separation{N,T}}, i::Integer)
    # println(i)

    if isleaf(tree, i)
        for child in tree.children[i]  # there might not be any
            traverse!(tree, child)
        end
    else
        inner, outer = tree.data[i].inner, tree.data[i].outer
        println(inner, outer, inner ∩ outer)
    end
end
#

# function simplify!{N,T}(tree::Tree{Separation{N,T}}, i::Integer)
#     # println(i)
#
#     for child in tree.children[i]  # there might not be any
#         simplify!(tree, child)
#     end
#
#     if isleaf(tree, i) && i != 1  # not root
#         j = setdiff(tree.children[tree.parent[i]], i)[1]  # sibling node
#
#         sep_i = tree.data[i]
#         sep_j = tree.data[j]
#         sep_parent = tree.data[tree.parent[i]]
#
#         # conditions from Jaulin + Desrochers 2014:
#         if isempty(sep_i.inner) || isempty(sep_i.outer) ||
#                 isempty(sep_j.inner) || isempty(sep_j.outer) ||
#
#                 sep_parent.inner ∩ sep_parent.outer !=
#                   hull(sep_i.inner ∩ sep_i.outer, sep_j.inner ∩ sep_j.outer)
#
#         end
#
#         new_parent_inner = sep_parent.inner ∪ sep_i.inner ∪ sep_j.inner
#
#     end
# end

function print_leaves{N,T}(tree::Tree{Separation{N,T}}, i::Integer)
    # println(i)

    for child in tree.children[i]  # there might not be any
        print_leaves(tree, child)
    end

    if isleaf(tree, i) && i != 1  # not root
        # j = setdiff(tree.children[tree.parent[i]], i)[1]  # sibling node
        #
        # sep_i = tree.data[i]
        # sep_j = tree.data[j]
        # sep_parent = tree.data[tree.parent[i]]
        #
        # # conditions from Jaulin + Desrochers 2014:
        # if isempty(sep_i.inner) || isempty(sep_i.outer) ||
        #         isempty(sep_j.inner) || isempty(sep_j.outer) ||
        #
        #         sep_parent.inner ∩ sep_parent.outer !=
        #           hull(sep_i.inner ∩ sep_i.outer, sep_j.inner ∩ sep_j.outer)
        #
        # end
        #
        # new_parent_inner = sep_parent.inner ∪ sep_i.inner ∪ sep_j.inner

        println("\nLeaf $i:")
        println("Parent: ", tree.data[tree.parent[i]])
        sibling = setdiff(tree.children[tree.parent[i]], i)[1]  # sibling node
        println("Node i: ", tree.data[i])
        println("Sibling: ", tree.data[sibling])


    end
end

isleaf(tree, i) = isempty(tree.children[i])

function newpave{N,T}(S::Separator, X::IntervalBox{N,T}, ϵ=0.1)

    separation = S(X)

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

        X = separation.inner ∩ separation.outer  # boundary

        if diam(X) < ϵ || isempty(X)
            continue
        end

        # old_diam = 2*diam(X)
        #
        # # repeatedly contract:
        # while diam(X) < 0.8 * old_diam
        #
        #     old_diam = diam(X)
        #     separation = S(X)
        #
        #     child = add_child!(tree, parent, separation)
        #     parent = child
        #
        #     X = separation.inner ∩ separation.outer
        #
        #     if diam(X) < ϵ || isempty(X)
        #         break
        #     end
        # end
        #
        # if diam(X) < ϵ || isempty(X)
        #     continue
        # end

        X1, X2 = IntervalConstraintProgramming.bisect(X)

        child1 = add_child!(tree, parent, S(X1))
        child2 = add_child!(tree, parent, S(X2))

        push!(working, child1, child2)

    end

    # simplify!(tree, 1)


    return tree

end
