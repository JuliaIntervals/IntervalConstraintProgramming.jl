struct Instruction
    op::Symbol
    out::Int32      # output slot
    arg1::Int32     # first input slot
    arg2::Int32     # second input slot (0 for unary; integer exponent for :pow_int)
end

"""
    CompiledDAG

A compiled representation of a SharedDAG optimized for fast propagation.
Converts the node graph into a flat instruction array operating on a
pre-allocated workspace of intervals. Each DAG node (variable, constant,
or operation) gets a slot in the workspace. Shared nodes (CSE) map to the
same slot, so backward contraction from multiple parents accumulates
correctly via intersection.

This eliminates:
- Dynamic dispatch on `node.op::Function` (replaced by Symbol comparison)
- Per-node allocation (pre-allocated flat workspace)
- Node traversal overhead (flat array iteration)
"""
struct CompiledDAG
    instructions::Vector{Instruction}
    workspace::Vector{Interval}
    n_vars::Int
    constant_slots::Vector{Int32}
    constant_values::Vector{Interval}
    root_slots::Vector{Int32}
    constraints::Vector{Interval}
end

const _OP_SYMBOL = Dict{Function, Symbol}(
    (+) => :add, (-) => :sub, (*) => :mul, (/) => :div, (^) => :pow,
    min => :min, max => :max,
    sin => :sin, cos => :cos, tan => :tan,
    asin => :asin, acos => :acos, atan => :atan,
    sinh => :sinh, cosh => :cosh, tanh => :tanh,
    asinh => :asinh, acosh => :acosh, atanh => :atanh,
    exp => :exp, exp2 => :exp2, exp10 => :exp10, expm1 => :expm1,
    log => :log, log2 => :log2, log10 => :log10, log1p => :log1p,
    sqrt => :sqrt, abs => :abs, sign => :sign,
)

"""
    compile(dag::SharedDAG) → CompiledDAG

Compile a SharedDAG into a flat instruction schedule. Each node in the DAG
gets a workspace slot (variables first, then constants, then operations).
Shared nodes get a single slot, preserving CSE.
"""
function compile(dag::SharedDAG)
    node_to_slot = Dict{AbstractNode, Int32}()
    slot = Int32(0)

    for v in dag.variables
        slot += Int32(1)
        node_to_slot[v] = slot
    end
    n_vars = Int(slot)

    constant_slots = Int32[]
    constant_values = Interval[]

    for node in dag.nodes
        haskey(node_to_slot, node) && continue
        slot += Int32(1)
        node_to_slot[node] = slot
        if node isa ConstantNode
            push!(constant_slots, slot)
            push!(constant_values, node.range)
        end
    end

    n_slots = Int(slot)
    workspace = fill(entireinterval(), n_slots)

    for (i, cs) in enumerate(constant_slots)
        workspace[cs] = constant_values[i]
    end

    instructions = Instruction[]
    for node in dag.nodes
        node isa OperationNode || continue
        out = node_to_slot[node]
        children = node.children

        if length(children) == 1
            a1 = node_to_slot[children[1]]
            op_sym = node.op === (-) ? :neg : get(_OP_SYMBOL, node.op, :unknown)
            push!(instructions, Instruction(op_sym, out, a1, Int32(0)))

        elseif length(children) == 2
            a1 = node_to_slot[children[1]]
            a2 = node_to_slot[children[2]]

            if node.op === (^) && children[2] isa ConstantNode
                n = children[2].value
                if n == round(Int, n)
                    push!(instructions, Instruction(:pow_int, out, a1, Int32(round(Int, n))))
                    continue
                end
            end

            op_sym = get(_OP_SYMBOL, node.op, :unknown)
            push!(instructions, Instruction(op_sym, out, a1, a2))
        end
    end

    root_slots = Int32[node_to_slot[e.root] for e in dag.constraints]
    constraints = Interval[e.constraint for e in dag.constraints]

    return CompiledDAG(instructions, workspace, n_vars,
                       constant_slots, constant_values, root_slots, constraints)
end

# --- Compiled forward pass ---

function forward!(cd::CompiledDAG, X::IntervalBox)
    ws = cd.workspace
    @inbounds for i in 1:cd.n_vars
        ws[i] = X[i]
    end
    @inbounds for (i, cs) in enumerate(cd.constant_slots)
        ws[cs] = cd.constant_values[i]
    end
    @inbounds for inst in cd.instructions
        ws[inst.out] = _fwd(inst.op, ws, inst.arg1, inst.arg2)
    end
end

function _fwd(op::Symbol, ws::Vector{Interval}, a1::Int32, a2::Int32)
    @inbounds begin
        op === :add && return ws[a1] + ws[a2]
        op === :sub && return ws[a1] - ws[a2]
        op === :mul && return ws[a1] * ws[a2]
        op === :div && return ws[a1] / ws[a2]
        op === :pow && return ws[a1] ^ ws[a2]
        op === :pow_int && return ws[a1] ^ Int(a2)
        op === :neg && return -ws[a1]
        op === :min && return IntervalArithmetic.min(ws[a1], ws[a2])
        op === :max && return IntervalArithmetic.max(ws[a1], ws[a2])
        op === :sin && return sin(ws[a1])
        op === :cos && return cos(ws[a1])
        op === :tan && return tan(ws[a1])
        op === :asin && return asin(ws[a1])
        op === :acos && return acos(ws[a1])
        op === :atan && return atan(ws[a1])
        op === :sinh && return sinh(ws[a1])
        op === :cosh && return cosh(ws[a1])
        op === :tanh && return tanh(ws[a1])
        op === :asinh && return asinh(ws[a1])
        op === :acosh && return acosh(ws[a1])
        op === :atanh && return atanh(ws[a1])
        op === :exp && return exp(ws[a1])
        op === :exp2 && return exp2(ws[a1])
        op === :exp10 && return exp10(ws[a1])
        op === :expm1 && return expm1(ws[a1])
        op === :log && return log(ws[a1])
        op === :log2 && return log2(ws[a1])
        op === :log10 && return log10(ws[a1])
        op === :log1p && return log1p(ws[a1])
        op === :sqrt && return sqrt(ws[a1])
        op === :abs && return abs(ws[a1])
        op === :sign && return sign(ws[a1])
    end
    return entireinterval()
end

# --- Compiled backward pass ---

function backward!(cd::CompiledDAG)
    ws = cd.workspace
    @inbounds for i in eachindex(cd.root_slots)
        rs = cd.root_slots[i]
        ws[rs] = IntervalArithmetic.intersect_interval(ws[rs], cd.constraints[i])
    end

    if all(@inbounds(isempty_interval(ws[rs])) for rs in cd.root_slots)
        @inbounds for i in 1:cd.n_vars
            ws[i] = emptyinterval()
        end
        return
    end

    @inbounds for i in length(cd.instructions):-1:1
        _bwd!(cd.instructions[i], ws)
    end
end

function backward!(cd::CompiledDAG, constraint::Interval)
    ws = cd.workspace
    @inbounds begin
        rs = cd.root_slots[1]
        ws[rs] = IntervalArithmetic.intersect_interval(ws[rs], constraint)
    end

    if @inbounds isempty_interval(ws[cd.root_slots[1]])
        @inbounds for i in 1:cd.n_vars
            ws[i] = emptyinterval()
        end
        return
    end

    @inbounds for i in length(cd.instructions):-1:1
        _bwd!(cd.instructions[i], ws)
    end
end

function _bwd!(inst::Instruction, ws::Vector{Interval})
    op = inst.op
    out = inst.out
    a1 = inst.arg1
    a2 = inst.arg2
    @inbounds z = ws[out]

    if isempty_interval(z)
        @inbounds ws[a1] = emptyinterval()
        @inbounds a2 > 0 && op !== :pow_int && (ws[a2] = emptyinterval())
        return
    end

    @inbounds begin
        if op === :add
            _, l, r = plus_rev(z, ws[a1], ws[a2])
            ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], l)
            ws[a2] = IntervalArithmetic.intersect_interval(ws[a2], r)
        elseif op === :sub
            _, l, r = minus_rev(z, ws[a1], ws[a2])
            ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], l)
            ws[a2] = IntervalArithmetic.intersect_interval(ws[a2], r)
        elseif op === :mul
            _, l, r = mul_rev(z, ws[a1], ws[a2])
            ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], l)
            ws[a2] = IntervalArithmetic.intersect_interval(ws[a2], r)
        elseif op === :div
            _, l, r = div_rev(z, ws[a1], ws[a2])
            ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], l)
            ws[a2] = IntervalArithmetic.intersect_interval(ws[a2], r)
        elseif op === :pow
            _, l, r = power_rev(z, ws[a1], ws[a2])
            ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], l)
            ws[a2] = IntervalArithmetic.intersect_interval(ws[a2], r)
        elseif op === :pow_int
            _, x_new, _ = power_rev(z, ws[a1], Int(a2))
            ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x_new)
        elseif op === :neg
            _, x = minus_rev(z, ws[a1])
            ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :min
            _, l, r = min_rev(z, ws[a1], ws[a2])
            ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], l)
            ws[a2] = IntervalArithmetic.intersect_interval(ws[a2], r)
        elseif op === :max
            _, l, r = max_rev(z, ws[a1], ws[a2])
            ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], l)
            ws[a2] = IntervalArithmetic.intersect_interval(ws[a2], r)
        elseif op === :sin;   _, x = sin_rev(z, ws[a1]);   ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :cos;   _, x = cos_rev(z, ws[a1]);   ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :tan;   _, x = tan_rev(z, ws[a1]);   ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :asin;  _, x = asin_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :acos;  _, x = acos_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :atan;  _, x = atan_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :sinh;  _, x = sinh_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :cosh;  _, x = cosh_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :tanh;  _, x = tanh_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :asinh; _, x = asinh_rev(z, ws[a1]); ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :acosh; _, x = acosh_rev(z, ws[a1]); ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :atanh; _, x = atanh_rev(z, ws[a1]); ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :exp;   _, x = exp_rev(z, ws[a1]);   ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :exp2;  _, x = exp2_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :exp10; _, x = exp10_rev(z, ws[a1]); ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :expm1; _, x = expm1_rev(z, ws[a1]); ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :log;   _, x = log_rev(z, ws[a1]);   ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :log2;  _, x = log2_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :log10; _, x = log10_rev(z, ws[a1]); ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :log1p; _, x = log1p_rev(z, ws[a1]); ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :sqrt;  _, x = sqrt_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :abs;   _, x = abs_rev(z, ws[a1]);   ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        elseif op === :sign;  _, x = sign_rev(z, ws[a1]);  ws[a1] = IntervalArithmetic.intersect_interval(ws[a1], x)
        end
    end
end

# --- Compiled propagation ---

function propagate!(cd::CompiledDAG, X::IntervalBox; max_iter::Int=10, tol::Float64=1e-10)
    ws = cd.workspace
    nv = cd.n_vars
    for _ in 1:max_iter
        forward!(cd, X)
        backward!(cd)
        X_new = IntervalBox(ntuple(i -> @inbounds(ws[i]), nv))
        isempty(X_new) && return X_new
        max_change = maximum(diam(X[i]) - diam(X_new[i]) for i in 1:nv)
        X = X_new
        max_change < tol && break
    end
    return X
end

function propagate!(cd::CompiledDAG, X::IntervalBox, constraint::Interval;
                    max_iter::Int=10, tol::Float64=1e-10)
    ws = cd.workspace
    nv = cd.n_vars
    for _ in 1:max_iter
        forward!(cd, X)
        backward!(cd, constraint)
        X_new = IntervalBox(ntuple(i -> @inbounds(ws[i]), nv))
        isempty(X_new) && return X_new
        max_change = maximum(diam(X[i]) - diam(X_new[i]) for i in 1:nv)
        X = X_new
        max_change < tol && break
    end
    return X
end
