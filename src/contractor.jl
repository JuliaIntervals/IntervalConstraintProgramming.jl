using ValidatedNumerics

include("reverse_mode.jl")

# Own version of gensym:
const symbol_number = [1]

doc"""Return a new unique symbol like z10"""
function make_symbol()
    i = symbol_number[1]
    symbol_number[1] += 1

    symbol("z", i)
end


doc"""`insert_variables` returns the head symbol (variable name) and the code
constructed by the tree beneath it in a depth-first search"""

function insert_variables(ex)  # numbers are leaves
    ex, Symbol[], quote end
end

function insert_variables(ex::Symbol)  # symbols are leaves
    ex, [ex], quote end
end


doc"""insert_variables replaces operations like `a+b` by assignments of the form `z10 = a+b`
in a recursive way,
using `make_symbol` to create a distinct symbol name of the form `z10`.

Returns: the variable at the head of the tree; the variables contained in the tree;
the code."""

function insert_variables(ex::Expr)

    op = ex.args[1]

    # rewrite +(a,b,c) as +(a,+(b,c))
    if op in (:+, :*) && length(ex.args) > 3
        return insert_variables( :( ($op)($(ex.args[2]), ($op)($(ex.args[3:end]...) )) ))
    end

    new_code = quote end
    current_args = []  # the arguments in the current expression that will be added
    all_vars = Symbol[]  # all variables contained in the sub-expressions

    for arg in ex.args[2:end]
        top, contained_vars, code = insert_variables(arg)

        push!(current_args, top)
        append!(all_vars, contained_vars)
        append!(new_code.args, code.args)  # add previously-generated code
    end

    new_var = make_symbol()

    top_level_code = :($(new_var) = ($op)($(current_args...)))  # new top-level code
    push!(new_code.args, top_level_code)

    return new_var, all_vars, new_code

end

doc"""`parse_comparison` parses single comparison expressions like `x >= 10`
into interval intersections

TODO: Allow something like [3,4]' for the complement of [3,4]'"""

function parse_comparison(ex)
    if ex.head != :comparison  # THIS IS ONLY JULIA 0.4; CHANGED IN 0.5
        throw(ArgumentError("Attempting to parse non-comparison $ex as comparison"))
    end

    op = ex.args[2]
    var = ex.args[1]
    value = ex.args[3]

    constraint = :()

    if op in (:<=, :≤)
        constraint = :(@interval(-∞, $value))
    elseif op in (:>=, :≥)
        constraint = :(@interval($value, ∞))
    elseif op in (:(==), :(=))
        constraint = :(@interval($value))
    end

    :($var = $var ∩ $constraint)
end


const rev_ops = Dict(:+ => :plusRev, :* => :mulRev, :^ => :powerRev, :- => :minusRev)

doc"""
`transform` takes in an expression like `x^2 + y^2 <= 1` and outputs
code for the forward-backward contractor

TODO: Add intersections in forward direction
"""
function transform(ex::Expr)

    root_var = :empty
    code = quote end

    # insert_variables generates code for the forward pass
    # the following is for Julia 0.4
    if ex.head == :comparison  # of form xˆ2 + y^2 <= 1
        root_var, all_vars, code = insert_variables(ex.args[1])
    else
        root_var, all_vars, code = insert_variables(ex)
    end

    new_code = copy(code)


    # change z10=a+b to z10=z10 ∩ (a+b) ?
    # for code_line in code.args  # each of form z10 = a + b
    #     var = code_line.args[1]
    #     rest = code_line.args[2:end]
    #
    #     intersection_code = :($(var) = $(var) ∩ $(rest...))
    #
    #     push!(new_code.args, intersection_code)
    # end


    if ex.head == :comparison

        new_ex = copy(ex)
        new_ex.args[1] = root_var

        push!(new_code.args, parse_comparison(new_ex))

    else
        # if just an expression with no comparison, assume that == 0
        constraint_code = :($(root_var) = $(root_var) ∩ @interval(0))
        push!(new_code.args, constraint_code)

    end


    # backwards pass: replace e.g. z = a + b with reverse mode functions like
    # plusRev(z, a, b)

    for i in reverse(code.args)  # run backwards
        if i.head == :(=)
            var = i.args[1]
            op = i.args[2].args[1]
            args = i.args[2].args[2:end]

            new_args = []
            push!(new_args, var)
            append!(new_args, args)

            rev_op = rev_ops[op]  # find the reverse operation

            rev_code = :($(rev_op)($(new_args...)))

            return_args = copy(new_args)

            # delete non-symbols in return args:
            for i in 1:length(return_args)
                if !(isa(return_args[i], Symbol))
                    return_args[i] = :_
                end
            end

            return_tuple = :()
            append!(return_tuple.args, return_args)

        end

        new_line = :($(return_tuple) = $(rev_code))
        push!(new_code.args, new_line)
    end

    new_code
end

"""Call as
```
C = @contractor(x, y, x^2 + y^2 <= 1)
x = y = @interval(0.5, 1.5)
C(x, y)
```

TODO: Hygiene for global variables, or pass in parameters
"""
macro contractor(ex...)

    code = transform(ex[end])

    vars = Expr(:tuple, ex[1:end-1]...)  # make a tuple out of the variables

    push!(code.args, :(return $vars))

    function_code = :( $(vars) -> $(code) )
    #function_code, ex[1:end-1]
    function_code
end

#= TODO:

=#

#function constraint_propagation(Cs::Vector{Function}, var)


# USAGE
