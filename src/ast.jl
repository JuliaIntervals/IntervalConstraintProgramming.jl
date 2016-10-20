
make_symbol() = make_symbol(:z)

function make_symbol(s::Symbol)

    i = get(symbol_numbers, s, 1)
    symbol_numbers[s] = i + 1

    Symbol("_", s, "_", i, "_")
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
type FlattenedAST
    input_variables::Set{Symbol}
    variables::Vector{Symbol}  # cleaned version
    intermediate::Vector{Symbol}  # generated vars
    code # ::Vector{Assignment}
end

import Base.show
function show(io::IO, flatAST::FlattenedAST)
    println(io, "input vars: ", flatAST.input_variables)
    println(io, "intermediate vars: ", flatAST.intermediate)
    println(io, "code: ")
    println(io, flatAST.code)
end

FlattenedAST() = FlattenedAST(Set{Symbol}(), [], [], [])

export FlattenedAST

##

export flatten!

doc"""`flatten!` adds information about any variables
generated to the `FlattenedAST` object. It returns the object
at the top of the current piece of tree."""
# process numbers
function flatten!(flatAST::FlattenedAST, ex)
    return ex  # nothing to do to the AST; return the number
end

function flatten!(flatAST::FlattenedAST, ex::Symbol)  # symbols are leaves
    push!(flatAST.input_variables, ex)  # add the discovered symbol as an input variable
    return ex
end


function flatten!(flatAST::FlattenedAST, ex::Expr)

    if ex.head == :$   # process constants of form $a
        process_constant!(flatAST, ex)

    elseif ex.head == :call
        process_call!(flatAST, ex)

    elseif ex.head == :(=)
        process_assignment!(flatAST, ex)

    elseif ex.head == :block
        process_block!(flatAST, ex)

    elseif ex.head == :tuple
        process_tuple!(flatAST, ex)

    elseif ex.head == :return
        process_return!(flatAST, ex)
    end
end

function process_constant!(flatAST::FlattenedAST, ex)
    return :(esc($(ex.args[1])))  # return the value of the constant
end

function process_block!(flatAST::FlattenedAST, ex)

    local top

    for arg in ex.args

        isa(arg, LineNumberNode) && continue

        top = flatten!(flatAST, arg)

    end

    return top  # last variable assigned
end


function process_tuple!(flatAST::FlattenedAST, ex)

    top_args = [flatten!(flatAST, arg) for arg in ex.args]

    #@show "Tuple arguments", top_args

    return top_args

end


function process_assignment!(flatAST::FlattenedAST, ex)
    process_call!(flatAST, ex.args[2], ex.args[1])
end


function process_call!(flatAST::FlattenedAST, ex, new_var=nothing)
    # new_var is an optional variable name to assign the result of the call to
    # if none is given, then a new, unique variable name is created

    op = ex.args[1]

    if isa(op, Expr) && op.head == :line
        return
    end

    # rewrite +(a,b,c) as +(a,+(b,c)):
    # TODO: Use @match here!

    # if op in (:+, :*) && length(ex.args) > 3
    #     return insert_variables( :( ($op)($(ex.args[2]), ($op)($(ex.args[3:end]...) )) ))
    # end

    # new_code = quote end
    # current_args = []  # the arguments in the current expression that will be added
    # all_vars = Set{Symbol}()  # all variables contained in the sub-expressions
    # generated_variables = Symbol[]

    top_args = []
    for arg in ex.args[2:end]

        isa(arg, LineNumberNode) && continue

        top = flatten!(flatAST, arg)
        push!(top_args, top)
    end

    top_level_code = quote end

    #@show op

    if op ∈ keys(rev_ops)  # standard operator
        if new_var == nothing
            new_var = make_symbol()
        end

        push!(flatAST.intermediate, new_var)

        top_level_code = Assignment(new_var, op, top_args)

    else
        if haskey(registered_functions, op)
            #println("Processing function $op")


            # make enough new variables for all the returned arguments:
            new_vars = Symbol[]

            for var in registered_functions[op].generated
                push!(new_vars, make_symbol())
            end

            append!(flatAST.intermediate, new_vars)

            top_level_code = FunctionAssignment(new_vars, op, top_args)

            new_var = new_vars[1:length(registered_functions[op].return_arguments)]


        else

            throw(ArgumentError("Function $op not supported"))
        end
    end


    push!(flatAST.code, top_level_code)

    return new_var

end

function flatten!(ex)
    flatAST = FlattenedAST()
    top_var = flatten!(flatAST, ex)

    return top_var, flatAST
end
