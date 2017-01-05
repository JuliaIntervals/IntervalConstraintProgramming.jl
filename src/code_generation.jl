
function make_tuple(args)

    if isa(args, Symbol)
        # args = [args]
        return args
    end

    length(args) == 1 && return args[1]

    return Expr(:tuple, args...)
end


function emit_forward_code(a::Assignment)

    args = isa(a.args, Vector) ? a.args : [a.args]

    lhs = make_tuple(a.lhs)

    if a.op == :()  # empty
        args = make_tuple(args)
        :($lhs = $args)

    else
        :($lhs = $(a.op)($(args...) ) )
    end
end


function emit_forward_code(a::FunctionAssignment)
    f = a.func
    args = isa(a.args, Vector) ? a.args : [a.args]
    lhs = make_tuple(a.lhs)

    :($lhs = $(esc(f)).forward($(a.args...) ) )
end


function emit_forward_code(code)  # code::Vector{Assignment})
    new_code = quote end
    new_code.args = vcat([emit_forward_code(line) for line in code])
    return new_code
end


function emit_backward_code(a::Assignment)

    args = isa(a.args, Vector) ? a.args : [a.args]

    return_args = [a.lhs, args...]
    rev_op = rev_ops[a.op]  # find reverse operation

    if rev_op == :()   # empty
        args = make_tuple(args)
        lhs = make_tuple(a.lhs)
        return :($args = $lhs)
        #return :($(args...) = $(a.lhs))
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



function forward_backward(flatAST::FlatAST)

    # @show flatAST.input_variables
    # @show flatAST.intermediate

    input = sort(collect(flatAST.input_variables))

    if isa(flatAST.top, Symbol)
        output = [flatAST.top]
    else
        output = flatAST.top
    end

    @show input
    @show flatAST.intermediate

    input = setdiff(input, flatAST.intermediate)  # remove local variables
    intermediate = setdiff(flatAST.intermediate, output)

    flatAST.variables = input

    code = emit_forward_code(flatAST.code)
    forward = make_function(input, [output; intermediate], code)

    code = emit_backward_code(flatAST.code)
    backward = make_function([input; output; intermediate],
                                input, code)

    # return GeneratedFunction(input, output, intermediate, code)

    return (forward, backward)
end


doc"""
Generate code for an anonymous function with given
input arguments, output arguments, and code block.
"""
function make_function(input_args, output_args, code)

    input = make_tuple(input_args)  # make a tuple of the variables
    output = make_tuple(output_args)  # make a tuple of the variables

    quote
        $input -> begin
                    $code
                    return $output
                  end
        end
end
