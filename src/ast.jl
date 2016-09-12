immutable Assignment
    lhs
    op
    args
end

# Close to single assignment form
type FlattenedAST
    input_variables::Vector{Symbol}  #
    intermediate::Vector{Symbol}  # generated vars
    code::Vector{Assignment}
end

import Base.show
function show(io::IO, flatAST::FlattenedAST)
    println(io, "input vars: ", flatAST.input_variables)
    println(io, "intermediate vars: ", flatAST.intermediate)
    println(io, "code: ")
    println(io, flatAST.code)
end

FlattenedAST() = FlattenedAST([], [], [])

export FlattenedAST


export insert_variables!


doc"""`insert_variables!` adds information about any variables
generated to the `FlattenedAST` object. It returns the object
at the top of the current piece of tree."""
# process numbers
function insert_variables!(flatAST::FlattenedAST, ex)
    return ex  # nothing to do to the AST; return the number
end

function insert_variables!(flatAST::FlattenedAST, ex::Symbol)  # symbols are leaves
    push!(flatAST.input_variables, ex)  # add the discovered symbol as an input variable
    return ex
end


function insert_variables!(flatAST::FlattenedAST, ex::Expr)

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


function process_tuple!(flatAST::FlattenedAST, ex)
    @show ex.args

    top_args = []
    for arg in ex.args

        isa(arg, LineNumberNode) && continue

        top = insert_variables!(flatAST, arg)
        push!(top_args, top)
    end

    @show top_args

    top_level_code = quote end

    # #@show op
    #
    # if op ∈ keys(rev_ops)  # standard operator
    #     #if new_var == nothing
    #         new_var = make_symbol()
    #     #end
    #
    #     push!(flatAST.intermediate, new_var)
    #
    #     top_level_code = Assignment(new_var, op, top_args)
    # end


    # push!(flatAST.code, top_level_code)

    # return new_var

    return Expr(:tuple, top_args...)

end

function process_call!(flatAST::FlattenedAST, ex)
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

        top = insert_variables!(flatAST, arg)
        push!(top_args, top)
    end

    top_level_code = quote end

    #@show op

    if op ∈ keys(rev_ops)  # standard operator
        #if new_var == nothing
            new_var = make_symbol()
        #end

        push!(flatAST.intermediate, new_var)

        top_level_code = Assignment(new_var, op, top_args)
    end


    push!(flatAST.code, top_level_code)

    return new_var

end

function insert_variables!(ex)
    flatAST = FlattenedAST()
    top_var = insert_variables!(flatAST, ex)

    return top_var, flatAST
end


function emit_forward_code(a::Assignment)
    :($(a.lhs) = $(a.op)($(a.args...) ) )
end

function emit_backward_code(a::Assignment)
    return_args = [a.lhs, a.args...]
    rev_op = rev_ops[a.op]  # find reverse operation

    rev_code = :($(rev_op)($(return_args...)))

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

function emit_backward_code(code::Vector{Assignment})
    new_code = quote end
    new_code.args = vcat([emit_backward_code(line) for line in reverse(code)])
    return new_code
end


function emit_forward_code(code::Vector{Assignment})
    new_code = quote end
    new_code.args = vcat([emit_forward_code(line) for line in code])
    return new_code
end


function forward_pass(flatAST::FlattenedAST)
    generated_code = emit_forward_code(flatAST.code)
    make_function(flatAST.input_variables, flatAST.intermediate, generated_code)
end

function backward_pass(flatAST::FlattenedAST)
    generated_code = emit_backward_code(flatAST.code)
    make_function([flatAST.input_variables; flatAST.intermediate],
                    flatAST.input_variables,
                    generated_code)
    # reverse input_variables and intermediate?

end
