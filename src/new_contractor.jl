struct Contractor{V, E, CC}
    vars::V
    ex::E
    contractor::CC
end

Contractor(ex, vars) = Contractor(vars, ex, forward_backward_contractor(ex, vars))

(CC::Contractor)(X, constraint=interval(0.0)) = IntervalBox(CC.contractor(X, constraint)[1])


abstract type AbstractSeparator end

"A separator models the inside and outside of a constraint set using a forward--backward contractor"
struct Separator{V,E,C,F,R} <: AbstractSeparator
    vars::V
    ex::E
    constraint::C
    f::F
    contractor::R
end

# Base.show(io::IO, S::Separator) = print(io, "Separator($(S.ex) ∈ $(S.constraint), vars = $(join(S.vars, ", ")))")

Base.show(io::IO, S::AbstractSeparator) = print(io, "Separator($(S.ex), vars=$(join(S.vars, ", ")))")

function Separator(orig_expr, vars)
    ex, constraint = analyse(orig_expr)
    
    return Separator(ex, vars, constraint)
end

Separator(ex, vars, constraint::Interval) = Separator(vars, ex ∈ constraint, constraint, make_function(ex, vars), Contractor(ex, vars))




"Returns boundary, inner, outer" 
function (SS::Separator)(X)
    boundary = SS.contractor(X)  # contract with respect to 0, which is always the boundary

    lb = IntervalBox(inf.(X))
    ub = IntervalBox(sup.(X))
    
    inner = boundary   
    outer = boundary

    if SS.f(lb) ⊆ SS.constraint
        inner = inner ∪ lb
    else
        outer = outer ∪ lb
    end
    
    if SS.f(ub) ⊆ SS.constraint
        inner = inner ∪ ub
    else
        outer = outer ∪ ub
    end
    

    return boundary, inner, outer 
end
