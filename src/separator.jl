type Separator
    variables::Vector{Symbol}
    separator::Function
end

function Separator(ex::Expr)
    expr, constraint = parse_comparison(ex)

    if isa(expr, Symbol)
        expr = :(1 * $expr)  # convert symbol into expression
    end

    C = Contractor(expr)
    variables = C.variables[2:end]

    a = constraint.lo
    b = constraint.hi

    local outer

    f = X -> begin

        inner = C(a..b, X...)  # closure over the function C

        if a == -∞
            outer = C(b..∞, X...)

        elseif b == ∞
            outer = C(-∞..a, X...)

        else

            outer1 = C(-∞..a, X...)
            outer2 = C(b..∞, X...)

            outer = [ hull(x1, x2) for (x1,x2) in zip(outer1, outer2) ]
        end

        return (inner, (outer...))

    end

    return Separator(variables, f)

end

macro separator(ex::Expr)
    Separator(ex)
end

macro constraint(ex::Expr)
    Separator(ex)
end

function Base.show(io::IO, S::Separator)
    println(io, "Separator:")
    print(io, "  - variables: $(S.variables)")
end


@compat (S::Separator)(X) = S.separator(X)

doc"Unify the variables of two separators"
function unify_variables(vars1, vars2)

    variables = unique(sort(vcat(vars1, vars2)))
    numvars = length(variables)  # total number of variables

    indices1 = indexin(vars1, variables)
    indices2 = indexin(vars2, variables)

    where1 = zeros(Int, numvars)  # inverse of indices1
    where2 = zeros(Int, numvars)

    for (i, which) in enumerate(indices1)
        where1[which] = i
    end

    for (i, which) in enumerate(indices2)
        where2[which] = i
    end

    return variables, indices1, indices2, where1, where2
end


# TODO: when S1 and S2 have different variables -- amalgamate!

doc"""
    ∩(S1::Separator, S2::Separator)

Separator for the intersection of two sets given by the separators `S1` and `S2`.
Takes an iterator of intervals (`IntervalBox`, tuple, array, etc.), of length
equal to the total number of variables in `S1` and `S2`;
it returns inner and outer tuples of the same length
"""
function Base.∩(S1::Separator, S2::Separator)

    variables, indices1, indices2, where1, where2 = unify_variables(S1.variables, S2.variables)
    numvars = length(variables)

    f = X -> begin

        inner1, outer1 = S1(tuple([X[i] for i in indices1]...))
        inner2, outer2 = S2(tuple([X[i] for i in indices2]...))

        if any(isempty, inner1)
            inner1 = emptyinterval(IntervalBox(X))
        else
            inner1 = [i ∈ indices1 ? inner1[where1[i]] : X[i] for i in 1:numvars]
        end

        if any(isempty, outer1)
            outer1 = emptyinterval(IntervalBox(X))
        else
            outer1 = [i ∈ indices1 ? outer1[where1[i]] : X[i] for i in 1:numvars]
        end

        if any(isempty, inner2)
            inner2 = emptyinterval(IntervalBox(X))
        else
            inner2 = [i ∈ indices2 ? inner2[where2[i]] : X[i] for i in 1:numvars]
        end

        if any(isempty, outer2)
            outer2 = emptyinterval(IntervalBox(X))
        else
            outer2 = [i ∈ indices2 ? outer2[where2[i]] : X[i] for i in 1:numvars]
        end


        # Treat as if had X[i] in the other directions, except if empty

        inner = tuple( [x ∩ y for (x,y) in zip(inner1, inner2) ]... )
        outer = tuple( [x ∪ y for (x,y) in zip(outer1, outer2) ]... )

        return (inner, outer)

    end

    return Separator(variables, f)

end

function Base.∪(S1::Separator, S2::Separator)

    variables, indices1, indices2, where1, where2 = unify_variables(S1.variables, S2.variables)
    numvars = length(variables)

    f = X -> begin
        inner1, outer1 = S1(tuple([X[i] for i in indices1]...))
        inner2, outer2 = S2(tuple([X[i] for i in indices2]...))

        if any(isempty, inner1)
            inner1 = emptyinterval(IntervalBox(X))
        else
            inner1 = [i ∈ indices1 ? inner1[where1[i]] : X[i] for i in 1:numvars]
        end

        if any(isempty, outer1)
            outer1 = emptyinterval(IntervalBox(X))
        else
            outer1 = [i ∈ indices1 ? outer1[where1[i]] : X[i] for i in 1:numvars]
        end

        if any(isempty, inner2)
            inner2 = emptyinterval(IntervalBox(X))
        else
            inner2 = [i ∈ indices2 ? inner2[where2[i]] : X[i] for i in 1:numvars]
        end

        if any(isempty, outer2)
            outer2 = emptyinterval(IntervalBox(X))
        else
            outer2 = [i ∈ indices2 ? outer2[where2[i]] : X[i] for i in 1:numvars]
        end


        inner = tuple( [x ∪ y for (x,y) in zip(inner1, inner2) ]... )
        outer = tuple( [x ∩ y for (x,y) in zip(outer1, outer2) ]... )

        return (inner, outer)
    end


    return Separator(variables, f)

end

import Base.!
function !(S::Separator)
    f = X -> begin
        inner, outer = S(X)
        return (outer, inner)
    end

    return Separator(S.variables, f)
end
