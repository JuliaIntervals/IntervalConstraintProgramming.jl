# Represent a sub-paving as a binary tree

using RecipesBase

immutable Tree{T}
    data::Vector{T}
    children::Vector{Vector{Int}}
    parent::Vector{Int}
end

Tree{T}(::Type{T}) = Tree(T[], Vector{Int}[], Int[])

Tree{T}(node::T) = Tree([node], [Int[]], [-1])  # -1 since no parent

# function Base.show{T}(io::IO, tree::Tree{T})
#     println(io, "Binary tree with $(length(tree.data)) nodes")
# end

function add_child!{T}(tree::Tree{T}, parent::Int, child::T)
    # add node:
    push!(tree.data, child)
    push!(tree.parent, parent)
    push!(tree.children, Int[])  # child has no children

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

"""
Extract the inner, outer and boundary subpavings from a tree.
"""
function extract_sets{T}(tree::Tree{Separation{2,T}})

    inner = vcat((setdiff(s.inner, s.outer) for s in tree.data if !isempty(s.inner))...)
    outer = vcat((setdiff(s.outer, s.inner) for s in tree.data if !isempty(s.outer))...)

    boundary = [s.outer ∩ s.inner for (i,s) in enumerate(tree.data) if isleaf(tree, i)]

    return inner, outer, boundary

end


@recipe function f(tree::Tree)

    inner, outer, boundary = extract_sets(tree)

    for i in 1:length(inner)
        @series begin
            c := :blue
            inner[i]
        end
    end

    for i in 1:length(boundary)
        @series begin
            c := :green
            boundary[i]
        end
    end


end

function draw(tree::IntervalConstraintProgramming.Tree; kw...)

    @show kw

    inner, outer, boundary = IntervalConstraintProgramming.extract_sets(tree)

    plot(inner; kw...)
    plot!(boundary; kw...)
    plot!(outer; kw...)
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


"""
Pave the set `S^{-1}(X)`.

Returns a tree of `Separation` objects.

The children of a node contain the information about which parts of the set are not outside (separation.inner) and not inside (separation.outer).
"""

function newpave{N,T}(S::Separator, X::IntervalBox{N,T}, ϵ=0.1)

    separation = S(X)

    tree = Tree(separation)
    working = [1]

    while !isempty(working)

        parent = pop!(working)
        separation = tree.data[parent]

        if isempty(separation.inner) || isempty(separation.outer)
            println("Found an empty")
            continue
        end

        X = separation.inner ∩ separation.outer  # boundary

        if diam(X) < ϵ || isempty(X)
            continue
        end

        X1, X2 = IntervalConstraintProgramming.bisect(X)

        child1 = add_child!(tree, parent, S(X1))
        child2 = add_child!(tree, parent, S(X2))

        push!(working, child1, child2)

    end

    # simplify!(tree, 1)


    return tree

end


boundary(s::Separation) = s.inner ∩ s.outer

"""
Check if a node is "minimal" (Jaulin-Desrochers, separators paper)
"""
function isminimal(tree, i)

    current = tree.data[i]

    (isempty(current.inner) || isempty(current.outer)) && return false

    isempty(tree.children[i]) && return true

    parent = tree.parent[i]
    child1, child2 = tree.children[parent]

    (boundary(tree.data[parent]) == boundary(tree.data[child1]) ∪ boundary(tree.data[child2])) && return true

    return false
end



#  Repeatedly contract:


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

inside(X::Separation) = setdiff(X.inner, X.outer)
outside(X::IntervalConstraintProgramming.Separation) = setdiff(X.outer, X.inner)
boundary(X::IntervalConstraintProgramming.Separation) = X.inner ∩ X.outer


"""
Reunite i, the sibling of i and the parent of i
"""
function reunite(tree, i)
    parent_index = tree.parent[i]
    child1_index = tree.children[parent_index][1]
    child2_index = tree.children[parent_index][1]

    parent = tree.data[parent_index]
    child1 = tree.data[child1_index]
    child2 = tree.data[child2_index]

    new_inside = reduce(union, vcat(inside(parent), inside(child1), inside(child2)))
    new_outside = reduce(union, vcat(outside(parent), outside(child1), outside(child2)))

    parent_full = union(parent.inner, parent.outer)

    new_inner = setdiff(parent_full, new_outside)
    new_outer = setdiff(parent_full, new_inside)

    new_parent = Separation(new_inner, new_outer)

end
