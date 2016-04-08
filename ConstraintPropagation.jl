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



doc"""`make_explicit` returns the head symbol (variable name) and the code
constructed by the tree beneath it in a depth-first search"""

function make_explicit(ex)  # symbols and numbers are leaves
    return ex, quote end
end


doc"""make_explicit replaces operations like `a+b` by assignments of the form `z10 = a+b`
in a recursive way,
using `make_symbol` to create a distinct symbol name of the form `z10`.

TODO: For later use, + and * should be split up into pairwise"""

function make_explicit(ex::Expr)

    op = ex.args[1]

    new_code = quote end
    vars = []

    for arg in ex.args[2:end]
        var, code = make_explicit(arg)

        push!(vars, var)
        append!(new_code.args, code.args)  # add previously-generated code
    end

    new_var = make_symbol()

    top_level_code = :($(new_var) = ($op)($(vars...)))  # current top-level code
    push!(new_code.args, top_level_code)

    return new_var, new_code

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


const rev_ops = Dict(:+ => :plusRev, :* => :mulRev, :^ => :powerRev)

doc"""
`transform` takes in an expression like `x^2 + y^2 <= 1` and outputs
code for the forward-backward contractor

TODO: Add intersections in forward direction
"""
function transform(ex::Expr)

    root_var = :empty
    code = quote end

    # make_explicit generates code for the forward pass
    if ex.head == :comparison  # of form xˆ2 + y^2 <= 1
        root_var, code = make_explicit(ex.args[1])
    else
        root_var, code = make_explicit(ex)
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
        constraint_code = :($(root_var) = $(root_var) ∩ :(@interval(0)))
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
C = @constructor(x, y, x^2 + y^2 <= 1)
x = y = @interval(0.5, 1.5)
C(x, y)
```

"""
macro constructor(ex...)
    @show ex

    inner_code = transform(ex[end])

    vars = :()
    append!(vars.args, [ex[1:end-1]...])

    push!(inner_code.args, :(return $vars))


    function_code = :( $(vars) -> $(inner_code) )
    @show function_code
end

# USAGE
