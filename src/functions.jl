#=

Want to process `@constraint f(f(x)) ∈ [0.3, 0.4]`
where `f(x) = 4x * (1-x)`

Given code `f(f(x))`, we need `f_forward` and `f_backward`.

Each "copy" of `f` uses the same actual forward and back functions,
`f.forward` and `f.backward`.

```
@function f(x) = 4x * (1-x)
```
should generate these forward and backward functions, and register the function
`f`.

"""
=#

type FunctionObject
    input_args::Vector{Symbol}
    output_args::Vector{Symbol}
    local_vars::Vector{Symbol}
    code::Expr
end


doc"""
A `ConstraintFunction` contains the created forward and backward
code
"""
type ConstraintFunction{F <: Function, G <: Function}
    input::Vector{Symbol}  # input arguments for forward function
    output::Vector{Symbol} # output arguments for forward function
    forward::F
    backward::G
end

type FunctionArguments
    # input::Vector{Symbol}  # input arguments for forward function
    # output::Vector{Symbol}  # output arguments
    # generated::Vector{Symbol} # local variables generated

    input
    generated
end

#const registered_functions = Dict{Symbol, ConstraintFunction}()

const function_arguments = Dict{Symbol, FunctionArguments}()


@doc """
`@function` registers a function to be used in forwards and backwards mode.

Example: `@function f(x, y) = x^2 + y^2`
"""  # this docstring does not work!

@eval macro ($(:function))(ex)   # workaround to define macro @function

    (f, args, code) = @match ex begin
        ( f_(args__) = code_ ) => (f, args, code)
    end
    @show f, args, code

    #root, all_vars, generated, code2 = IntervalConstraintProgramming.insert_variables!(code)
    root, flatAST = IntervalConstraintProgramming.insert_variables!(code)

    #@show root, all_vars, generated, code2

    forward_code = forward_pass(flatAST) #root, all_vars, generated, code2)
    backward_code = backward_pass(flatAST) #root, all_vars, generated, code2)

    @show forward_code, backward_code

    function_arguments[f] = FunctionArguments(flatAST.input_variables, flatAST.intermediate)


    return quote
        #$(esc(Meta.quot(f))) = ConstraintFunction($(all_vars), $(generated), $(forward_code), $(backward_code))
        $(esc(f)) = ConstraintFunction($(flatAST.input_variables), $(flatAST.intermediate), $(forward_code), $(backward_code))
        #registered_functions[$(Meta.quot(f))] =  ConstraintFunction($(all_vars), $(generated), $(forward_code), $(backward_code))
        #$(Meta.quot(f)) =  ConstraintFunction($(all_vars), $(generated), $(forward_code), $(backward_code))
    end
end


function match_function(ex)
    try

        f, args, body =
            @match ex begin
             ( (f_(args__) = body_) |
              (function f_(args__) body_ end)) => (f, args, body)
           end

         return (f, args, body)

    catch
        throw(ArgumentError("$ex does not have the form of a function"))
    end
end
