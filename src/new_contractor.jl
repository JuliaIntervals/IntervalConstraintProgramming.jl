### contractors


# TODO: Rename to ForwardBackwardContractor
struct Contractor{V, E, C, P}
    vars::V
    ex::E
    contractor::C
    parameters::P
end

Contractor(vars::V, ex::E, contractor::C, parameters::P) where {V, E, C, P} =
    Contractor{V, E, C, P}(vars, ex, contractor, parameters)

# forward_backward_contractor from ReversePropagation creates the forward--backward contractor
function Contractor(ex, vars, params)
    return Contractor(vars, ex, forward_backward_contractor(ex, vars, params), Sym[])
end

Contractor(ex, vars) = Contractor(ex, vars, Sym[])  # no parameters

Contractor(ex) = Contractor(ex, Symbolics.get_variables(ex))

"Apply contractor to contract with respect to f(x) ∈ constraint_set"

(CC::Contractor)(X, constraint_set, params) =
    ( (a, b) = CC.contractor(X, constraint_set, params); (IntervalBox(a), b) )



### Separators


abstract type AbstractSeparator end

"A separator models the inside and outside of a constraint set using a forward--backward contractor"
struct Separator{V, E, C, R, P} <: AbstractSeparator
    vars::V
    ex::E
    constraint_set::C
    contractor::R
    parameters::P
end

Separator(vars::V, ex::E, constraint_set::C, contractor::R, parameters::P) where {V, E, C, R, P} =
    Separator{V, E, C, R, P}(vars, ex, constraint_set, contractor, parameters)



# Base.show(io::IO, S::Separator) = print(io, "Separator($(S.ex) ∈ $(S.constraint), vars = $(join(S.vars, ", ")))")

Base.show(io::IO, S::AbstractSeparator) = print(io, "Separator($(S.ex), vars=$(join(S.vars, ", ")))")

# function Separator(orig_expr, vars)
#     ex, constraint = normalise(orig_expr)

#     return Separator(ex, vars, constraint)
# end

function Separator(orig_expr, vars, params)
    ex, constraint = normalise(orig_expr)

    return Separator(ex, vars, constraint, params)
end

Separator(ex, vars, constraint_set::Interval) =
    Separator(vars, ex ∈ constraint_set, constraint_set, Contractor(ex, vars), Sym[])

Separator(ex, vars, constraint_set::Interval, params) =
    Separator(vars, ex ∈ constraint_set, constraint_set, Contractor(ex, vars, params), params)




"Returns boundary, inner, outer"
function (S::Separator)(X, params)
    boundary = S.contractor(X, interval(0), params)[1]  # contract with respect to 0, which is always the boundary

    lb = IntervalBox(inf.(X))
    ub = IntervalBox(sup.(X))

    inner = boundary
    outer = boundary

    # TODO: Correct treatment of infinite upper/lower bounds

    if S.contractor(lb, interval(0), params)[2] ⊆ S.constraint_set
        inner = inner ∪ lb
    else
        outer = outer ∪ lb
    end

    if S.contractor(ub, interval(0), params)[2] ⊆ S.constraint_set
        inner = inner ∪ ub
    else
        outer = outer ∪ ub
    end


    # lb_image = SS.f(lb)
    # if !isempty(lb_image) && (lb_image ⊆ SS.constraint)
    #     inner = inner ∪ lb
    # else
    #     outer = outer ∪ lb
    # end

    # ub_image = SS.f(ub)
    # if !isempty(ub_image) && (ub_image ⊆ SS.constraint)
    #     inner = inner ∪ ub
    # else
    #     outer = outer ∪ ub
    # end

    return boundary, inner, outer
end

