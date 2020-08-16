# Implement reverse-mode AD after contraction

## Following Neumaier & Schichl, Vanaret

const bar = '̄'  #  bar symbol
barred(s::Symbol) = Symbol(s, bar)

barred(x) = :(_)



struct Adjoint{O}
    op::O
end

(a::typeof(Adjoint(*)))(x, y) = (y, x)
(a::typeof(Adjoint(+)))(x, y) = (one(x), one(y))
(a::typeof(Adjoint(-)))(x, y) = (one(x), -one(y))



function forward_code(a::Assignment)

    # args = isa(a.args, Vector) ? a.args : [a.args]

    # lhs = make_tuple(a.lhs)

    pullback = Symbol(a.lhs, "_pullback")
    lhs = make_tuple([a.lhs, pullback])

    return :($lhs = rrule($(a.op), $(a.args...) ) )
end



function adjoint_code(a::Assignment)
    barred_args = barred.(a.args)
    barred_lhs = barred(a.lhs)
    pullback =  Symbol(a.lhs, "_pullback")
    args_tuple = make_tuple(a.args)

    result_vars = [:_]
    code = []

    for (i, var) in enumerate(a.args)
        if var isa Symbol
            result_var = Symbol("r", i)
            push!(result_vars, result_var)
            push!(code, :($(barred_args[i]) += $(result_var)))
        
        else
            push!(result_vars, :_)
        end
    end

    result_tuple = make_tuple(result_vars)
    pushfirst!(code, :($(result_tuple) = $(pullback)($(barred_lhs))))

    return code

end



function forward_pass(flatAST)
    return quote
        $(forward_code.(flatAST.code)...)
    end
end

function reverse_pass(flatAST)

    top = flatAST.top
    intermediates = setdiff(flatAST.intermediate, [flatAST.top])

    initialization_code = [ :( $(barred(var)) = zero($var) )
                                for var in vcat(flatAST.input_variables, intermediates) ]

    push!(initialization_code, :($(barred(top)) = one($top)))    

    return quote
        $(initialization_code...)
        $(vcat(adjoint_code.(reverse(flatAST.code))...)...) 
    end
end



function process_AST_args(flatAST::FlatAST)
    input = collect(flatAST.input_variables)

    # @show flatAST.top

    if isa(flatAST.top, Symbol)
        output = [flatAST.top]

    elseif isa(flatAST.top, Expr) && flatAST.top.head == :tuple
        output = flatAST.top.args

    else
        output = flatAST.top
        # @show output
    end

    # @show input
    # @show flatAST.intermediate
    # @show output

    input = setdiff(input, flatAST.intermediate)  # remove local variables
    intermediate = setdiff(flatAST.intermediate, output)

    return input, intermediate, output
end


function reverse_mode_AD(flatAST::FlatAST)

    top = flatAST.top
    intermediates = setdiff(flatAST.intermediate, [flatAST.top])


    initialization_code = [ :( $(barred(var)) = zero($var) )
                                for var in vcat(flatAST.input_variables, intermediates) ]

    push!(initialization_code, :($(barred(top)) = one($top)))


    reverse_AD_code = quote end
    reverse_AD_code = adjoint_code.(reverse(flatAST.code))

    adjoint_variables = make_tuple(barred.(flatAST.input_variables))
    # return_code = :(return $(adjoint_variables))

    code = Expr(:block, initialization_code..., reverse_AD_code...)


    (input, output, intermediate) = process_AST_args(flatAST)
    make_function([input, output, intermediate], [barred.(flatAST.input_variables)], code)
end
