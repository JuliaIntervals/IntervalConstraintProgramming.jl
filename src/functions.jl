

doc"""
A `ConstraintFunction` contains the created forward and backward
code
"""
type ConstraintFunction{F <: Function, G <: Function}
    input::Vector{Symbol}  # input arguments for forward function
    output::Vector{Symbol} # output arguments for forward function
    forward::F
    backward::G
    forward_code::Expr
    backward_code::Expr
end

type FunctionArguments
    # input::Vector{Symbol}  # input arguments for forward function
    # output::Vector{Symbol}  # output arguments
    # generated::Vector{Symbol} # local variables generated

    input
    generated
    return_arguments
end



const registered_functions = Dict{Symbol, FunctionArguments}()


@doc """
`@function` registers a function to be used in forwards and backwards mode.

Example: `@function f(x, y) = x^2 + y^2`
"""  # this docstring does not work!

@eval macro ($(:function))(ex)   # workaround to define macro @function

    (f, args, code) = match_function(ex)

    return_arguments, flatAST = flatten(code)

    # make into an array:
    if !(isa(return_arguments, Array))
        return_arguments = [return_arguments]
    end

    # rearrange so actual return arguments come first:

    flatAST.intermediate = setdiff(flatAST.intermediate, return_arguments)

    # println("HERE")
    flatAST.intermediate = [return_arguments; flatAST.intermediate]


    registered_functions[f] = FunctionArguments(flatAST.variables, flatAST.intermediate, return_arguments)

    forward, backward = forward_backward(flatAST)



    return quote

        $(esc(f)) =
            ConstraintFunction($(flatAST.variables),
                                $(flatAST.intermediate),
                                $(forward),
                                $(backward),
                                $(Meta.quot(forward)),
                                $(Meta.quot(backward))
                                )

    end

end


function match_function(ex)

    try
        @capture ex begin
            (   (f_(args__) = body_)
                  | (function f_(args__) body_ end) )
           end

         return (f, args, rmlines(body))  # rmlines is from MacroTools package

    catch
        throw(ArgumentError("$ex does not have the form of a function"))
    end
end
