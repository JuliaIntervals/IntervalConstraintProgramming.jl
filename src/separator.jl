abstract Separator


doc"""
ConstraintSeparator is a separator that represents a constraint defined directly
using `@constraint`.
"""
# CHANGE TO IMMUTABLE AND PARAMETRIZE THE FUNCTION FOR EFFICIENCY
type ConstraintSeparator <: Separator
    variables::Vector{Symbol}
    separator::Function
    contractor::Contractor
    expression::Expr
end

doc"""CombinationSeparator is a separator that is a combination (union, intersection,
or complement) of other separators.
"""
type CombinationSeparator <: Separator
    variables::Vector{Symbol}
    separator::Function
    expression::Expr
end

doc"""Create a ConstraintSeparator from a given constraint expression."""
function ConstraintSeparator(ex::Expr)
    expr, constraint = parse_comparison(ex)

    if constraint == entireinterval()
        throw(ArgumentError("Must give explicit constraint"))
    end

    if isa(expr, Symbol)
        expr = :(1 * $expr)  # convert symbol into expression
    end

    #C = @contractor($expr)
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

    expression = :($expr ∈ $constraint)

    return ConstraintSeparator(variables, f, C, expression)

end

macro separator(ex::Expr)  # alternative name for constraint -- remove?
    ex = Meta.quot(ex)
    :(ConstraintSeparator($ex))
end

doc"""Create a separator from a given constraint expression, written as
standard Julia code.

e.g. `C = @constraint x^2 + y^2 <= 1`

The variables (`x` and `y`, in this case) are automatically inferred.
External constants can be used as e.g. `$a`:

```
a = 3
C = @constraint x^2 + y^2 <= $a
```
"""
macro constraint(ex::Expr)
    ex = Meta.quot(ex)
    :(ConstraintSeparator($ex))
end

function show(io::IO, S::Separator)
    println(io, "Separator:")
    print(io, "- variables: ")
    print(io, join(map(string, S.variables), ", "))
    println(io)
    print(io, "- expression: ")
    println(io, S.expression)
end

show_code(S::ConstraintSeparator) = show_code(S.contractor)

@compat (S::ConstraintSeparator)(X) = S.separator(X)
@compat (S::CombinationSeparator)(X) = S.separator(X)

# show_code(S::Separator) = show_code(S.contractor)


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
function ∩(S1::Separator, S2::Separator)

    variables, indices1, indices2, where1, where2 = unify_variables(S1.variables, S2.variables)
    numvars = length(variables)

    f = X -> begin

        inner1, outer1 = S1([X[i] for i in indices1])
        inner2, outer2 = S2([X[i] for i in indices2])

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

    expression = :($(S1.expression) ∩ $(S2.expression))

    return CombinationSeparator(variables, f, expression)

end

function ∪(S1::Separator, S2::Separator)

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

    expression = :($(S1.expression) ∪ $(S2.expression))


    return CombinationSeparator(variables, f, expression)

end

function !(S::Separator)
    f = X -> begin
        inner, outer = S(X)
        return (outer, inner)
    end

    expression = :(!($(S.expression)))

    return CombinationSeparator(S.variables, f, expression)
end
