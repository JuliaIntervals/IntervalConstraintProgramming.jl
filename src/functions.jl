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
    input_args::Vector{Symbol}
    output_args::Vector{Symbol}
    forward_function::Function
    backward_function::Function
end

doc"""
A `FunctionWrapper` specifies the actual variables that will be used as
input and output for a given invocation of a given function.
"""
type FunctionWrapper
    input_args::Vector{Symbol}
    output_args::Vector{Symbol}
    constraint_function::ConstraintFunction
end

const registered_functions = Dict{Symbol, ConstraintFunction}()
const function_wrappers = Dict{Symbol, FunctionWrapper}()


const function_counters = Dict{Symbol, Int}()

function increment_counter!(f::Symbol)
    function_counters[f] = get(function_counters, f, 0) + 1
    counter = function_counters[f]

    return counter, symbol("_", f, counter, "_")
end


macro make_function(ex)
    @show ex

    (f, args, code) = @match ex begin
        ( f_(args__) = code_ ) => (f, args, code)
    end
    @show f, args, code

    forward_code = IntervalConstraintProgramming.forward_pass(code)
    backward_code = IntervalConstraintProgramming.backward_pass(code)

    @show forward_code, backward_code

    forward_function = eval(forward_code)
    backward_function = eval(backward_code)


    return nothing
end

# usage:  @make_function f(x) = x^2

#function register_function(name::Symbol, )
