abstract type Separator end


"""
ConstraintSeparator is a separator that represents a constraint defined directly
using `@constraint`.
"""
struct ConstraintSeparator{C, II, ex<:Union{Operation,Expr}} <: Separator
    variables::Vector{Symbol}
    constraint::II  # Interval or IntervalBox
    contractor::C
    expression::ex
end

ConstraintSeparator(constraint, contractor, expression) = ConstraintSeparator(contractor.variables, constraint, contractor, expression)

"""CombinationSeparator is a separator that is a combination (union, intersection,
or complement) of other separators.
"""
struct CombinationSeparator{F, ex<:Union{Operation,Expr}} <: Separator
    variables::Vector{Symbol}
    separator::F
    expression::ex
end

function (S::ConstraintSeparator)(X::IntervalBox)
    C = S.contractor
    a, b = S.constraint.lo, S.constraint.hi

    inner = C(IntervalBox(Interval(a, b)), X)

    local outer

    if a == -∞
        outer = C(IntervalBox(Interval(b, ∞)), X)

    elseif b == ∞
        outer = C(IntervalBox(Interval(-∞, a)), X)

    else

        outer1 = C(IntervalBox(Interval(-∞, a)), X)
        outer2 = C(IntervalBox(Interval(b, ∞)), X)

        outer = outer1 ∪ outer2
    end

    return (inner, outer)
end



"""`parse_comparison` parses comparisons like `x >= 10`
into the corresponding interval, expressed as `x ∈ [10,∞]`

Returns the expression and the constraint interval

TODO: Allow something like [3,4]' for the complement of [3,4]
"""

function parse_comparison(ex::Expr)
    expr, limits =
    @match ex begin
       ((a_ <= b_) | (a_ < b_) | (a_ ≤ b_))   => (a, (-∞, b))
       ((a_ >= b_) | (a_ > b_) | (a_ ≥ b_))   => (a, (b, ∞))
       ((a_ == b_) | (a_ = b_))   => (a, (b, b))

       ((a_ <= b_ <= c_)
        | (a_ < b_ < c_)
        | (a_ <= b_ < c)
        | (a_ < b_ <= c))         => (b, (a, c))

       ((a_ >= b_ >= c_)
       | (a_ > b_ > c_)
       | (a_ >= b_ > c_)
       | (a_ > b_ >= c))          => (b, (c, a))

       ((a_ ∈ [b_, c_])
       | (a_ in [b_, c_])
       | (a_ ∈ b_ .. c_)
       | (a_ in b_ .. c_))        => (a, (b, c))

       _                          => (ex, (-∞, ∞))

   end

   a, b = limits
   return (expr, a..b)   # expr ∈ [a,b]

end

function parse_comparison(ex::Operation)

    if isa(ex.args[1], ModelingToolkit.Constant)
        if ex.op == <
            a = ex.args[1].value
            b = Inf
        elseif ex.op == >
            a = -Inf
            b = ex.args[1].value
        end
        return (ex.args[2], a..b)
    elseif isa(ex.args[2], ModelingToolkit.Constant)
        if ex.op == >
            a = ex.args[2].value
            b = Inf
        elseif ex.op == <
            a = -Inf
            b = ex.args[2].value
        else
            a = ex.args[2].value
            b = ex.args[2].value
        end
        return (ex.args[1], a..b)
    end

end



function new_parse_comparison(ex)
    # @show ex
    if @capture ex begin
            (op_(a_, b_))
        end

        #return (op, a, b)
        # @show op, a, b

    elseif ex.head == :comparison
        println("Comparison")
        symbols = ex.args[1:2:5]
        operators = ex.args[2:2:4]

        # @show symbols
        # @show operators

    end
end

function make_constraint(expr, constraint, var =[])

    if isa(expr, Symbol)
        expr = :(1 * $expr)  # make into an expression!
    end

    contractor_name = make_symbol(:C)

    full_expr = Meta.quot(:($expr ∈ $constraint))

    contractor_code = make_contractor(expr, var)

    code = quote end
    push!(code.args, :($(esc(contractor_name)) = $(contractor_code)))

    push!(code.args, :(ConstraintSeparator($constraint, $(esc(contractor_name)), $full_expr)))

    code
end

make_constraint(expr::Variable, constraint) = make_constraint(Operation(expr), constraint)


function make_constraint(expr::Operation, constraint, var=[])
    C = Contractor(var, expr)
    ex = expr ∈ constraint
    ConstraintSeparator(constraint, C, ex)
end


"""Create a separator from a given constraint expression, written as
standard Julia code.

e.g. `C = @constraint x^2 + y^2 <= 1`

The variables (`x` and `y`, in this case) are automatically inferred.
External constants can be used as e.g. `\$a`:

```
a = 3
C = @constraint x^2 + y^2 <= \$a
```
"""
macro constraint(ex::Expr, variables = [])
    expr, constraint = parse_comparison(ex)
    isa(variables, Array) ? var = [] : var = variables.args
    make_constraint(expr, constraint, var)
end

"""
Create a separator without the use of macros using ModelingToolkit

e.g  vars = @variables x y z
S = Separator(vars, x^2+y^2<1)
X= IntervalBox(-0.5..1.5, -0.5..1.5, -0.5..1.5)
S(X)
"""
function Separator(variables, ex::Operation)
    expr, constraint = parse_comparison(ex)
    var = [Symbol(i) for i in variables]
    make_constraint(expr, constraint, var)
end

Separator(ex::Operation) = Separator([], ex)

Separator(vars::Array{Variable}, f) = Separator(vars, f(vars...))

Separator(vars, f) = Separator(vars, f([Variable(Symbol(i)) for i in vars]...))  # if vars is not vector of variables

function show(io::IO, S::Separator)
    println(io, "Separator:")
    print(io, "  - variables: ")
    print(io, join(map(string, S.variables), ", "))
    println(io)
    print(io, "  - expression: ")
    print(io, S.expression)
end


(S::CombinationSeparator)(X) = S.separator(X)


"Unify the variables of two separators"
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

"""
    ∩(S1::Separator, S2::Separator)

Separator for the intersection of two sets given by the separators `S1` and `S2`.
Takes an iterator of intervals (`IntervalBox`, tuple, array, etc.), of length
equal to the total number of variables in `S1` and `S2`;
it returns inner and outer tuples of the same length
"""
function ∩(S1::Separator, S2::Separator)

    #=variables, indices1, indices2, where1, where2 = unify_variables(S1.variables, S2.variables)
    numvars = length(variables)=#
    variables = S1.variables   # as S1 and S2 have same variables
    f = X -> begin

       inner1, outer1 = S1(X)
       inner2, outer2 = S2(X)
       inner = inner1 ∩ inner2
       outer = outer1 ∪ outer2

        #=
        inner1, outer1 = S1(IntervalBox([X[i] for i in indices1]...))
        inner2, outer2 = S2(IntervalBox([X[i] for i in indices2]...))

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

        inner = IntervalBox( [x ∩ y for (x,y) in zip(inner1, inner2) ]... )
        outer = IntervalBox( [x ∪ y for (x,y) in zip(outer1, outer2) ]... )
        =#

        return (inner, outer)

    end

    expression = :($(S1.expression) ∩ $(S2.expression))

    return CombinationSeparator(variables, f, expression)

end

function ∪(S1::Separator, S2::Separator)

    #=variables, indices1, indices2, where1, where2 = unify_variables(S1.variables, S2.variables)
    numvars = length(variables)=#
    variables = S1.variables    # S1 and S2 have same variables
    f = X -> begin

        inner1, outer1 = S1(X)
        inner2, outer2 = S2(X)
        inner = inner1 ∪ inner2
        outer = outer1 ∩ outer2

        #=
        inner1, outer1 = S1(IntervalBox([X[i] for i in indices1]...))
        inner2, outer2 = S2(IntervalBox([X[i] for i in indices2]...))

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


        inner = IntervalBox( [x ∪ y for (x,y) in zip(inner1, inner2) ]... )
        outer = IntervalBox( [x ∩ y for (x,y) in zip(outer1, outer2) ]... )
        =#

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
