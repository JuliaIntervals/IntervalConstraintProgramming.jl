

struct Model
    vars::Set{Sym{Real, Nothing}}
    params 
    constraints 
end

Model() = Model(Set([]), Set([]), [])

add_variable!(m::Model, v::Num) = add_variable!(m, value(v))
add_variable!(m::Model, v::Sym) = push!(m.vars, v)

function add_variables!(m::Model, vars)
    for var in vars
        add_variable!(m, var)
    end
end

function add_constraint!(m::Model, s::Num)
    # push!(m.vars, s.vars...)
    push!(m.constraints, s)
end





variables(m::Model) = sort(collect(m.vars), lt = (x, y) -> x.name < y.name)


extract_vars(ex) = Symbol[]
extract_vars(ex::Symbol) = [ex]

function extract_vars(ex::Expr)
    if ex.head == :call
        reduce(vcat, extract_vars.(ex.args[2:end]))

    else
        reduce(vcat, extract_vars.(ex.args))
    end
end

function add_constraint!(m, ex::Expr)
    # @show m, ex

    m2 = esc(m)

    vars = extract_vars(ex)

    @show vars

    # create variables in global scope:
    code = [:($(esc(v)) = Sym{Real}($(Meta.quot(v)))) for v in vars]
    
    code2 = [:(push!($(m2).vars, $(esc(v)))) for v in vars]
    
    @show code

    quote
        $(code...) 
        $(code2...)

        push!($(m2).constraints, $(esc(ex)))
    end

end

macro constraint(m, ex)
    # @show m, ex

    add_constraint!(m, ex)
end


# m = Model()
# @constraint(m, x^2 + y^2 <= 1)

# separator(m.constraints[1], sort(collect(m.vars), lt = (x, y) -> x.name < y.name))

# @constraint(m, z < 3)

# separator(m.constraints[1], sort(collect(m.vars), lt = (x, y) -> x.name < y.name))


# rename to ConstraintSatisfactionProblem?
struct ConstraintProblem
    vars
    constraint_expressions 
    constraints
end

function ConstraintProblem(vars, constraint_exprs)
    constraints = constraint.(constraint_exprs, Ref(vars))

    return ConstraintProblem(vars, constraint_exprs, constraints)
end

function ConstraintProblem(constraint_exprs)

    vars = collect(reduce(∪, Symbolics.get_variables.(constraint_exprs)))

    return ConstraintProblem(vars, constraint_exprs)
end



