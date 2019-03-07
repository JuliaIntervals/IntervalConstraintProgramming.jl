

"""
A `ConstraintFunction` contains the created forward and backward
code
"""
mutable struct ConstraintFunction{F <: Function, G <: Function}
    input::Vector{Symbol}  # input arguments for forward function
    output::Vector{Symbol} # output arguments for forward function
    forward::F
    backward::G
    forward_code::Expr
    backward_code::Expr
    expression::Expr
end

function (C::ConstraintFunction)(args...) #To access forward function call f(X) and for backward function call f(A,X)
                                          #where A is constraint

    if length(args)==1
        X=args[1]
        return C.forward(X)
    else
        A=args[1]
        X=args[2]

        if isa(A,Interval)
            A=IntervalBox(A)
        end

        output, intermediate = C.forward(X)

        output_box = IntervalBox(output)
        constrained = output_box ∩ A

        if isempty(constrained)
            return emptyinterval(X)
        end

        return IntervalBox(C.backward(X, constrained, intermediate) )
    end

end

function Base.show(io::IO, f::ConstraintFunction{F,G}) where {F,G}
    println(io, "ConstraintFunction:")
    println(io, "  - input arguments: $(f.input)")
    println(io, "  - output arguments: $(f.output)")
    print(io, "  - expression: $(MacroTools.striplines(f.expression))")
end


struct FunctionArguments
    input
    return_arguments
    intermediate
end



const registered_functions = Dict{Symbol, FunctionArguments}()


# """
# `@function` registers a function to be used in forwards and backwards mode.
#
# Example: `@function f(x, y) = x^2 + y^2`
# """  # this docstring does not work!
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
    # flatAST.intermediate = [return_arguments; flatAST.intermediate]




    forward, backward = forward_backward(flatAST)

    registered_functions[f] = FunctionArguments(
            flatAST.variables, return_arguments, flatAST.intermediate)


    return quote

        $(esc(f)) =
            ConstraintFunction($(flatAST.variables),
                                $(flatAST.intermediate),
                                $(forward),
                                $(backward),
                                $(Meta.quot(forward)),
                                $(Meta.quot(backward)),
                                $(Meta.quot(ex))
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
