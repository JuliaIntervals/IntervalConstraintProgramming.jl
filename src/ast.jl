const symbol_numbers = Dict{Symbol, Int}()

"""Return a new, unique symbol like _z3_"""
function make_symbol(s::Symbol)  # default is :z

    i = get(symbol_numbers, s, 0)
    symbol_numbers[s] = i + 1

    if i == 0
        return Symbol("_", s)
    else
        return Symbol("_", s, i)
    end
end

make_symbol(c::Char) = make_symbol(Symbol(c))

let current_symbol = 'a'
    global function make_symbol()
        current_sym = current_symbol

        if current_sym < 'z'
            current_symbol += 1
        else
            current_symbol = 'a'
        end

        return make_symbol(current_sym)

    end
end

make_symbols(n::Integer) = [make_symbol() for i in 1:n]

make_symbols(v::Vector{Symbol}) = make_symbols(length(v))


# The following function is not used
"""Check if a symbol like `:a` has been uniqued to `:_a_1_`"""
function isuniqued(s::Symbol)
    ss = string(s)
    contains(ss, "_") && isdigit(ss[end-1])
end

# Types for representing a flattened AST:

# Combine Assignment and FunctionAssignment ?

struct Assignment
    lhs
    op
    args
end

struct FunctionAssignment
    f  # function name
    args  # input arguments
    return_arguments
    intermediate  # tuple of intermediate variables
end

# Close to single assignment form
mutable struct FlatAST
    top  # topmost variable(s)
    input_variables::Vector{Symbol}
    intermediate::Vector{Symbol}  # generated vars
    code # ::Vector{Assignment}
    variables::Vector{Symbol}  # cleaned version of input_variables
end


function Base.show(io::IO, flatAST::FlatAST)
    println(io, "top: ", flatAST.top)
    println(io, "input vars: ", flatAST.input_variables)
    println(io, "intermediate vars: ", flatAST.intermediate)
    println(io, "code: ", flatAST.code)
end

FlatAST() = FlatAST([], [], [], [], [])

export FlatAST

##

set_top!(flatAST::FlatAST, vars) = flatAST.top = vars  # also returns vars

add_variable!(flatAST::FlatAST, var) = push!(flatAST.input_variables, var)

add_intermediate!(flatAST::FlatAST, var::Symbol) = push!(flatAST.intermediate, var)
add_intermediate!(flatAST::FlatAST, vars::Vector{Symbol}) = append!(flatAST.intermediate, vars)

add_code!(flatAST::FlatAST, code) = push!(flatAST.code, code)

export flatten


function flatten(ex, var = [])
    ex = MacroTools.striplines(ex)
    flatAST = FlatAST()
    if !isempty(var)
        for i in var push!(flatAST.input_variables, i) end
    end
    top = flatten!(flatAST, ex, var)

    return top, flatAST
end

"""`flatten!` recursively converts a Julia expression into a "flat" (one-dimensional)
structure, stored in a FlatAST object. This is close to SSA (single-assignment form,
https://en.wikipedia.org/wiki/Static_single_assignment_form).

Variables that are found are considered `input_variables`.
Generated variables introduced at intermediate nodes are stored in
`intermediate`.
Returns the variable at the top of the current piece of the tree."""

# TODO: Parameters

# numbers:
function flatten!(flatAST::FlatAST, ex::ModelingToolkit.Constant, var)
    return ex.value  # nothing to do the AST; return the number
end

function flatten!(flatAST::FlatAST, ex, var)
    return ex  # nothing to do to the AST; return the number
end

# symbols:
function flatten!(flatAST::FlatAST, ex::Variable, var)  # symbols are leaves
        if isempty(var)
            add_variable!(flatAST, Symbol(ex))  # add the discovered symbol as an input variable
        end
    return Symbol(ex)
end

function flatten!(flatAST::FlatAST, ex::Symbol, var)
    if isempty(var)
        add_variable!(flatAST, ex)  # add the discovered symbol as an input variable
    end
   return ex
end

function flatten!(flatAST::FlatAST, ex::Expr, var = [])
    local top

    if ex.head == :$    # constants written as $a
        top = process_constant!(flatAST, ex)

    elseif ex.head == :call  # function calls
        top = process_call!(flatAST, ex, var)

    elseif ex.head == :(=)  # assignments
        top = process_assignment!(flatAST, ex)

    elseif ex.head == :block
        top = process_block!(flatAST, ex)

    elseif ex.head == :tuple
        top = process_tuple!(flatAST, ex)

    elseif ex.head == :return
        top = process_return!(flatAST, ex)

    else
        error("Currently unable to process expressions with ex.head=$(ex.head)")

    end

    set_top!(flatAST, top)
end

function flatten!(flatAST::FlatAST, ex::Operation, var)
    if typeof(ex.op) == Variable
        return flatten!(flatAST, ex.op, var)
    else
       top = process_operation!(flatAST, ex, var)
       set_top!(flatAST, top)
    end
end


function process_constant!(flatAST::FlatAST, ex)
    return esc(ex.args[1])  # interpolate the value of the external constant
end


"""A block represents a linear sequence of Julia statements.
They are processed in order.
"""

function process_block!(flatAST::FlatAST, ex)
    local top

    for arg in ex.args
        isa(arg, LineNumberNode) && continue
        top = flatten!(flatAST, arg)
    end

    return top  # last variable assigned
end

# function process_iterated_function!(flatAST::FlatAST, ex)

function process_tuple!(flatAST::FlatAST, ex)
    # println("Entering process_tuple")
    # @show flatAST
    # @show ex

    top_args = [flatten!(flatAST, arg) for arg in ex.args]

    # top_args = []  # the arguments returned for each element of the tuple
    # for arg in ex.args
    #     top = flatten!(flatAST, arg)
    #     push!(top_args, top)
    # end

    return top_args

end

"""An assigment is of the form a = f(...).
The name a is currently retained.
TODO: It should later be made unique.
"""
function process_assignment!(flatAST::FlatAST, ex)
    # println("process_assignment!:")
    #  @show ex
    #  @show ex.args[1], ex.args[2]

    top = flatten!(flatAST, ex.args[2])
    # @show top

    var = ex.args[1]
    # @show var

    # TODO: Replace the following by multiple dispatch
    if isa(var, Expr) && var.head == :tuple
        vars = [var.args...]

    elseif isa(var, Tuple)
        vars = [var...]

    elseif isa(var, Vector)
        vars = var

    else
        vars = [var]
    end

    add_intermediate!(flatAST, vars)

    top_level_code = Assignment(vars, :(), top)  # empty operation
    add_code!(flatAST, top_level_code)

    # j@show flatAST

    return var

end

"""Processes something of the form `(f↑4)(x)` (write as `\\uparrow<TAB>`)
by rewriting it to the equivalent set of iterated functions"""
function process_iterated_function!(flatAST::FlatAST, ex)
    total_function_call = ex.args[1]
    args = ex.args[2:end]

    # @show args

    function_name = total_function_call.args[2]
    power = total_function_call.args[3]  # assumed integer

    new_expr = :($function_name($(args...)))

    # @show new_expr

    for i in 2:power
        new_expr = :($function_name($new_expr))
    end

    # @show new_expr

    flatten!(flatAST, new_expr)  # replace the current expression with the new one
end

"""A call is something like +(x, y).
A new variable is introduced for the result; its name can be specified
    using the new_var optional argument. If none is given, then a new, generated
    name is used.
"""
function process_call!(flatAST::FlatAST, ex, var = [], new_var=nothing)

    #println("Entering process_call!")
    #@show ex
    #@show flatAST
    #@show new_var
    op = ex.args[1]
    #@show op

    if isa(op, Expr)
        if op.head == :line
            return

        elseif op.head == :call && op.args[1]==:↑   # iterated function like f ↑ 4
            return process_iterated_function!(flatAST, ex)
        end

    end

    # rewrite +(a,b,c) as +(a,+(b,c)) by recursive splitting
    # TODO: Use @match here!

    if op in (:+, :*) && length(ex.args) > 3
        return flatten!(flatAST, :( ($op)($(ex.args[2]), ($op)($(ex.args[3:end]...) )) ), var)
    end

    top_args = []
    for arg in ex.args[2:end]

        isa(arg, LineNumberNode) && continue
        top = flatten!(flatAST, arg, var)

        if isa(top, Vector)  # TODO: make top always a Vector?
            append!(top_args, top)

        else
            push!(top_args, top)
        end
    end

    top_level_code = quote end

    #@show op

    if op ∈ keys(reverse_operations)  # standard operator
        if new_var == nothing
            new_var = make_symbol()
        end

        add_intermediate!(flatAST, new_var)

        top_level_code = Assignment(new_var, op, top_args)

    else
        if haskey(registered_functions, op)

            f = registered_functions[op]

            # make enough new variables for all the returned arguments:
            return_args = make_symbols(f.return_arguments)

            intermediate = make_symbols(f.intermediate) #registered_functions[op].intermediate  # make_symbol(:z_tuple)

            add_intermediate!(flatAST, return_args)
            add_intermediate!(flatAST, intermediate)

            top_level_code = FunctionAssignment(op, top_args, return_args, intermediate)

            new_var = return_args


        else

            throw(ArgumentError("Function $op not available. Use @function to define it."))
        end
    end


    add_code!(flatAST, top_level_code)

    return new_var

end


function process_operation!(flatAST::FlatAST, ex, var, new_var=nothing)

    op = ex.op

    if op in (+, *) && length(ex.args) > 2
        return flatten!(flatAST, Expression( (op)((ex.args[1]), (op)((ex.args[2:end]...) )) ), var)
    end

    top_args = []
    for arg in ex.args[1:end]

        isa(arg, LineNumberNode) && continue
        top = flatten!(flatAST, arg, var)

        if isa(top, Vector)
            append!(top_args, top)

        else
            push!(top_args, top)
        end
    end

    top_level_code = quote end

    #@show op

    if Symbol(op) ∈ keys(reverse_operations)  # standard operator
        if new_var == nothing
            new_var = make_symbol()
        end

        add_intermediate!(flatAST, new_var)

        top_level_code = Assignment(new_var, Symbol(op), top_args)

    else
        if haskey(registered_functions, Symbol(op))

            f = registered_functions[Symbol(op)]

            # make enough new variables for all the returned arguments:
            return_args = make_symbols(f.return_arguments)

            intermediate = make_symbols(f.intermediate) #registered_functions[op].intermediate  # make_symbol(:z_tuple)

            add_intermediate!(flatAST, return_args)
            add_intermediate!(flatAST, intermediate)

            top_level_code = FunctionAssignment(Symbol(op), top_args, return_args, intermediate)

            new_var = return_args


        else

            throw(ArgumentError("Function $op not available. Use @function to define it."))
        end
    end

    add_code!(flatAST, top_level_code)
    return new_var

end
