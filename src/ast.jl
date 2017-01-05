
const symbol_numbers = Dict{Symbol, Int}()

doc"""Return a new, unique symbol like _z3_"""
function make_symbol(s::Symbol = :z)  # default is :z

    i = get(symbol_numbers, s, 1)
    symbol_numbers[s] = i + 1

    Symbol("_$(s)_$(i)_")
end


function make_symbols(n::Integer)
    [make_symbol() for i in 1:n]
end

doc"""Check if a symbol like `:a` has been uniqued to `:_a_1_`"""
function isuniqued(s::Symbol)
    ss = string(s)
    contains(ss, "_") && isdigit(ss[end-1])
end

# Types for representing a flattened AST:

immutable Assignment
    lhs
    op
    args
end

immutable FunctionAssignment
    lhs
    func
    args
end

immutable GeneratedFunction
    input_arguments::Vector{Symbol}
    output_arguments::Vector{Symbol}
    code::Expr
end

# Close to single assignment form
type FlatAST
    top  # topmost variable(s)
    input_variables::Set{Symbol}
    variables::Vector{Symbol}  # cleaned version
    intermediate::Vector{Symbol}  # generated vars
    code # ::Vector{Assignment}
end


function Base.show(io::IO, flatAST::FlatAST)
    println(io, "top: ", flatAST.top)
    println(io, "input vars: ", flatAST.input_variables)
    println(io, "intermediate vars: ", flatAST.intermediate)
    println(io, "code: ", flatAST.code)
end

FlatAST() = FlatAST([], Set{Symbol}(), [], [], [])

export FlatAST

##

set_top!(flatAST::FlatAST, vars) = flatAST.top = vars

add_variable!(flatAST::FlatAST, var) = push!(flatAST.input_variables, var)

add_intermediate!(flatAST::FlatAST, var::Symbol) = push!(flatAST.intermediate, var)
add_intermediate!(flatAST::FlatAST, vars::Vector{Symbol}) = append!(flatAST.intermediate, vars)

add_code!(flatAST::FlatAST, code) = push!(flatAST.code, code)

export flatten


function flatten(ex)
    flatAST = FlatAST()
    top_var = flatten!(flatAST, ex)

    return top_var, flatAST
end


doc"""`flatten!` recursively converts a Julia expression into a "flat" (one-dimensional)
structure, stored in a FlatAST object. This is close to SSA (single-assignment form,
 https://en.wikipedia.org/wiki/Static_single_assignment_form).

 Variables that are found are considered `input_variables`.
 Generated variables introduced at intermediate nodes are stored in
 `intermediate`.
 The function returns the variable that is
at the top of the current piece of the tree."""
# process numbers
function flatten!(flatAST::FlatAST, ex)
    set_top!(flatAST, ex)  # nothing to do to the AST; return the number
end

function flatten!(flatAST::FlatAST, ex::Symbol)  # symbols are leaves
    add_variable!(flatAST, ex)  # add the discovered symbol as an input variable
    return ex
end


function flatten!(flatAST::FlatAST, ex::Expr)
    local top

    if ex.head == :$    # constants written as $a
        top = process_constant!(flatAST, ex)

    elseif ex.head == :call  # function calls
        top = process_call!(flatAST, ex)

    elseif ex.head == :(=)  # assignments
        top = process_assignment!(flatAST, ex)

    elseif ex.head == :block
        top = process_block!(flatAST, ex)

    elseif ex.head == :tuple
        top = process_tuple!(flatAST, ex)

    elseif ex.head == :return
        top = process_return!(flatAST, ex)
    end

    set_top!(flatAST, top)
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
    # top_args = [flatten!(flatAST, arg) for arg in ex.args]

    top_args = []  # the arguments returned for each element of the tuple
    for arg in ex.args
        top = flatten!(flatAST, arg)
        push!(top_args, top)
    end

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
function process_call!(flatAST::FlatAST, ex, new_var=nothing)

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

    # rewrite +(a,b,c) as +(a,+(b,c)):
    # TODO: Use @match here!

    if op in (:+, :*) && length(ex.args) > 3
        return flatten!(flatAST,
            :( ($op)($(ex.args[2]), ($op)($(ex.args[3:end]...) )) )
            )
    end

    # new_code = quote end
    # current_args = []  # the arguments in the current expression that will be added
    # all_vars = Set{Symbol}()  # all variables contained in the sub-expressions
    # generated_variables = Symbol[]

    top_args = []
    for arg in ex.args[2:end]

        isa(arg, LineNumberNode) && continue

        top = flatten!(flatAST, arg)

        if isa(top, Vector)  # TODO: make top always a Vector?
            append!(top_args, top)

        else
            push!(top_args, top)
        end
    end

    top_level_code = quote end

    #@show op

    if op ∈ keys(rev_ops)  # standard operator
        if new_var == nothing
            new_var = make_symbol()
        end

        add_intermediate!(flatAST, new_var)

        top_level_code = Assignment(new_var, op, top_args)

    else
        if haskey(registered_functions, op)

            # make enough new variables for all the returned arguments:
            new_vars = make_symbols(length(registered_functions[op].generated))

            add_intermediate!(flatAST, new_vars)

            top_level_code = FunctionAssignment(new_vars, op, top_args)

            new_var = new_vars[1:length(registered_functions[op].return_arguments)]


        else

            throw(ArgumentError("Function $op not available. Use @function to define it."))
        end
    end


    add_code!(flatAST, top_level_code)

    return new_var

end
