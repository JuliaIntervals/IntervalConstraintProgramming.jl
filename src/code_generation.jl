"""
A generated function, with the code that generated it
"""
struct GeneratedFunction{F}
    f::F
    code::Expr
end


#GeneratedFunction(code::Expr) = GeneratedFunction(eval(code), code)

(f::GeneratedFunction{F})(x...) where {F} = f.f(x...)


function make_tuple(args)

    if isa(args, Symbol)
        # args = [args]
        return args
    end

    length(args) == 1 && return args[1]

    return Expr(:tuple, args...)
end


function really_make_tuple(args)

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


function emit_backward_code(a::Assignment)

    args = isa(a.args, Vector) ? a.args : [a.args]

    return_args = [a.lhs, args...]
    rev_op = reverse_operations[a.op]  # find reverse operation

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


# TODO: Just pass intermediate as tuple between forward and backward for functions

function emit_forward_code(a::FunctionAssignment)
    f = a.f

    args = isa(a.args, Vector) ? a.args : [a.args]
    args_tuple = really_make_tuple(args)

    return_tuple = really_make_tuple(a.return_arguments)
    intermediate = really_make_tuple(a.intermediate)

    # Remove the following once https://github.com/JuliaLang/julia/issues/20524 fixed and replace with
    # :( ( $return_tuple, $intermediate ) = $(esc(f)).forward($args_tuple))

    temp1 = make_symbol(:z_tuple)
    temp2 = make_symbol(:z_tuple)

    return quote
        ($temp1, $temp2) = $(esc(f)).forward($args_tuple)
        $return_tuple = $temp1
        $intermediate = $temp2
    end
end

function emit_backward_code(a::FunctionAssignment)
    f = a.f

    args = isa(a.args, Vector) ? a.args : [a.args]
    args_tuple = really_make_tuple(args)

    intermediate = really_make_tuple(a.intermediate)

    return_tuple = really_make_tuple(a.return_arguments)

    :($args_tuple = $(esc(f)).backward($args_tuple, $return_tuple, $intermediate))
end


function emit_forward_code(code)  # code::Vector{Assignment})
    new_code = quote end
    new_code.args = vcat([emit_forward_code(line) for line in code])
    return new_code
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

    flatAST.variables = input

    forward_code = emit_forward_code(flatAST.code)
    forward = make_forward_function(input, output, intermediate, forward_code)

    # @show input
    # @show intermediate
    # @show output

    backward_code = emit_backward_code(flatAST.code)
    backward = make_backward_function(input, output, intermediate,
                                input, backward_code)

    # @show input
    # @show output
    # @show intermediate

    return (forward, backward)
end


"""
Generate code for an anonymous function with given
input arguments, output arguments, and code block.
"""
function make_forward_function(input_args, output_args, intermediate, code)

    input = really_make_tuple(input_args)  # make a tuple of the variables
    intermediate = really_make_tuple(intermediate)
    output = make_tuple(output_args)  # make a tuple of the variables

    quote
        t -> begin
                $input = t
                $code
                return ($output, $intermediate)
            end
    end
end

function make_backward_function(input1, input2, input3, output_args, code)

    input1 = really_make_tuple(input1)  # make a tuple of the variables
    input2 = really_make_tuple(input2)
    input3 = really_make_tuple(input3)
    output = really_make_tuple(output_args)  # make a tuple of the variables

    quote
        (t1, t2, t3) -> begin
            $input1 = t1
            $input2 = t2
            $input3 = t3
            $code
            return $output
        end
    end
end
