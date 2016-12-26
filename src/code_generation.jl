
function make_tuple(args)
    length(args) == 1 && return args[1]

    return Expr(:tuple, args...)
end


function emit_forward_code(a::Assignment)

    args = isa(a.args, Vector) ? a.args : [a.args]

    if a.op == :()  # empty
        :($(a.lhs) = $(args...) )

    else
        :($(a.lhs) = $(a.op)($(args...) ) )
    end
end


function emit_forward_code(a::FunctionAssignment)
    f = a.func
    args = make_tuple(a.lhs)
    :($args = $(esc(f)).forward($(a.args...) ) )
end


function emit_forward_code(code) #code::Vector{Assignment})
    new_code = quote end
    new_code.args = vcat([emit_forward_code(line) for line in code])
    return new_code
end



function emit_backward_code(a::Assignment)

    args = isa(a.args, Vector) ? a.args : [a.args]


    return_args = [a.lhs, args...]
    rev_op = rev_ops[a.op]  # find reverse operation

    if rev_op == :()   # empty
        return :($(args...) = $(a.lhs))
    else
        rev_code = :($(rev_op)($(return_args...)))
    end

    # delete non-symbols in return args:
    for (i, arg) in enumerate(return_args)
        if !(isa(arg, Symbol))
            return_args[i] = :_
        end
    end

    return_tuple = Expr(:tuple, return_args...)  # make tuple out of array
# or: :($(return_args...),)

    return :($(return_tuple) = $(rev_code))

end

function emit_backward_code(a::FunctionAssignment)
    f = a.func

    input_args = [a.args; a.lhs]

    output_args = make_tuple(a.args)

    :($output_args = $(esc(f)).backward($(input_args...) ) )
end


function emit_backward_code(code) #::Vector{Assignment})
    new_code = quote end
    new_code.args = vcat([emit_backward_code(line) for line in reverse(code)])
    return new_code
end



function forward_pass(flatAST::FlattenedAST)

    # @show flatAST.input_variables
    # @show flatAST.intermediate

    input_variables = sort(collect(flatAST.input_variables))
    input_variables = setdiff(input_variables, flatAST.intermediate)  # remove local variables
    flatAST.variables = input_variables  # why??

    generated_code = emit_forward_code(flatAST.code)
    #make_function(input_variables, flatAST.intermediate, generated_code)
    return GeneratedFunction(input_variables, flatAST.intermediate, generated_code)
end

function backward_pass(flatAST::FlattenedAST)

    generated_code = emit_backward_code(flatAST.code)
    # make_function([flatAST.variables; flatAST.intermediate],
    #                 flatAST.variables,
    #                 generated_code)
    # # reverse input_variables and intermediate?

    all_variables = [flatAST.variables; flatAST.intermediate]
    return GeneratedFunction(all_variables,
                            flatAST.variables,
                            generated_code)
end


doc"""
Generate code for an anonymous function with given
input arguments, output arguments, and code block.
"""
function make_function(input_args, output_args, code)

    input = make_tuple(input_args)  # make a tuple of the variables
    output = make_tuple(output_args)  # make a tuple of the variables

    return quote
                $input -> begin
                            $code
                            return $output
                        end
                end



end

make_function(f::GeneratedFunction) =
        make_function(f.input_arguments, f.output_arguments, f.code)
