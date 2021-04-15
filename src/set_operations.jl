
struct CombinationSeparator{V, E, F} <: AbstractSeparator
    vars::V
    ex::E
    f::F
end


function ∩(S1::AbstractSeparator, S2::AbstractSeparator)

    vars = S1.vars   # assume S1 and S2 have same variables
    
    f = X -> begin

       boundary1, inner1, outer1 = S1(X)
       boundary2, inner2, outer2 = S2(X)
       
       inner = inner1 ∩ inner2
       outer = outer1 ∪ outer2

       boundary = inner ∩ outer 
       
       return (boundary, inner, outer)

    end

    ex = (S1.ex) ∩ (S2.ex)

    return CombinationSeparator(vars, ex, f)

end



function ∪(S1::AbstractSeparator, S2::AbstractSeparator)

    vars = S1.vars   # assume S1 and S2 have same variables
    
    f = X -> begin

       boundary1, inner1, outer1 = S1(X)
       boundary2, inner2, outer2 = S2(X)
       
       inner = inner1 ∪   inner2
       outer = outer1 ∩ outer2

       boundary = inner ∩ outer 
       
       return (boundary, inner, outer)

    end

    ex = (S1.ex) ∪ (S2.ex)

    return CombinationSeparator(vars, ex, f)

end



function ¬(S::AbstractSeparator)

    vars = S.vars   # assume S1 and S2 have same variables
    
    f = X -> begin

       boundary, inner, outer = S(X)
     
       return (boundary, outer, inner)

    end

    ex = ¬(S.ex)

    return CombinationSeparator(vars, ex, f)

end

Base.:!(S::AbstractSeparator) = ¬(S)



(S::CombinationSeparator)(X) = S.f(X)


Base.setdiff(S1::AbstractSeparator, S2::AbstractSeparator) = S1 ∩ ¬(S2)
Base.symdiff(S1::AbstractSeparator, S2::AbstractSeparator) = setdiff(S1, S2) ∪ setdiff(S2, S1)

## TODO: Make separate type