#=

Want to process `@constraint f(f(x)) ∈ [0.3, 0.4]`
where `f(x) = 4x * (1-x)`

Given code `f(f(x))`, we need `f_forward` and `f_backward`.
Replace the code with

`_f1_(_f2_(x))`

since when generate the code, functions `f1` and `f2` need different *arguments*,
and need to remember the arguments between the forward and reverse pass.
Nonetheless, each "copy" of `f` uses the same actual forward and back functions,
`_f_forward_` and `_f_reverse_`.

```
@function f(x) = 4x * (1-x)
```
should generate these forward and backward functions, and register the function
`f`.

"""
=#

doc"""
A `ConstraintFunction` contains the created forward and backward
code
"""
type ConstraintFunction
    input::Vector{Symbol}  # input arguments for forward function
    output::Vector{Symbol} # output arguments for forward function
    # forward_code::Expr
    # backward_code::Expr
    forward::Function
    backward::Function
end

# doc"""
# A `FunctionWrapper` specifies the actual variables that will be used as
# input and output for a given invocation of a given function.
# """
# type FunctionWrapper
#     input_args::Vector{Symbol}
#     output_args::Vector{Symbol}
#     constraint_function::ConstraintFunction
# end

const registered_functions = Dict{Symbol, ConstraintFunction}()
# const function_wrappers = Dict{Symbol, FunctionWrapper}()
#
#
# const function_counters = Dict{Symbol, Int}()
#
# function increment_counter!(f::Symbol)
#     function_counters[f] = get(function_counters, f, 0) + 1
#     counter = function_counters[f]
#
#     return counter, symbol("_", f, counter, "_")
# end


macro make_function(ex)
    @show ex

    (f, args, code) = @match ex begin
        ( f_(args__) = code_ ) => (f, args, code)
    end
    @show f, args, code

    root, all_vars, generated, code = IntervalConstraintProgramming.insert_variables(code)

    forward_code = forward_pass(root, all_vars, generated, code)
    backward_code = backward_pass(root, all_vars, generated, code)

    @show forward_code, backward_code

    return quote
        #$(esc(f)) = ConstraintFunction($(all_vars), $(generated), $(forward_code), $(backward_code))
        registered_functions[$(Meta.quot(f))] =  ConstraintFunction($(all_vars), $(generated), $(forward_code), $(backward_code))
    end
end

# usage:  @make_function f(x) = x^2

#function register_function(name::Symbol, )
