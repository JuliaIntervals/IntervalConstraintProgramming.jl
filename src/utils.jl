

"""
    exactify(ex)

Walk `ex` and replace every non-`Bool` `Real` literal with `IntervalArithmetic.exact(literal)`.

Used on the `Expr` produced by symbolic code generation (`Symbolics.build_function`
or `ReversePropagation.forward_backward_expr`) so that, when the generated function
is called on `Interval` arguments, numeric literals from the user's constraint
(like the `1` in `x^2 + y^2 == 1`) are treated as exact and do not introduce the
"NG" (not-guaranteed) flag in the result.
"""
exactify(ex::Bool) = ex
exactify(ex::Real) = :($(IntervalArithmetic.exact)($ex))
exactify(ex::Expr) = Expr(ex.head, exactify.(ex.args)...)
exactify(ex) = ex


# --- decoration preservation for HC4Revise ---------------------------------
#
# IEEE 1788 weakens `intersect_interval(a, b)` to the `trv` decoration because,
# in general, the intersection may not be the range of any function. In
# HC4Revise however each intersection/reverse op is narrowing *within* an
# already-evaluated function range, so `min(decoration(inputs)...)` is the
# right answer. The helpers below re-decorate the output accordingly; the
# Expr walker `preserve_decorations!` rewrites the call sites that RP's
# `forward_backward_expr` emits so the weakening never takes hold.

_dec_of(x::Interval) = decoration(x)
_dec_of(x) = IntervalArithmetic.com

_min_input_decoration(inputs::Tuple) = minimum(_dec_of, inputs)

# Re-decorate an interval with `d`. Used to undo the `trv` weakening that
# `intersect_interval` and reverse ops perform: in HC4 the output is always a
# subset of one of the inputs, so `d = min(decoration(inputs)...)` is the valid
# decoration, regardless of what the op itself stamped on. Empty intervals
# stay as-is (`trv` / empty semantics).
_redecorate(x::Interval, d::IntervalArithmetic.Decoration) =
    isempty_interval(x) ? x : interval(inf(x), sup(x), d)
_redecorate(x, ::IntervalArithmetic.Decoration) = x

"Wrap an `intersect_interval`-style call: single interval result."
function preserve_dec_intersect(result::Interval, inputs::Tuple)
    return _redecorate(result, _min_input_decoration(inputs))
end

"Wrap a reverse-op call: tuple result, each interval element re-decorated."
function preserve_dec_reverse(result::Tuple, inputs::Tuple)
    d = _min_input_decoration(inputs)
    return map(x -> _redecorate(x, d), result)
end


# ---- Expr walker ----------------------------------------------------------
#
# Matches the two forms RP's generated body emits:
#   _lhs = (IntervalArithmetic.intersect_interval)(a, b)
#   (t1, t2, …) = (ReversePropagation.var"_rev_OP")(arg1, arg2, …)
# and rewrites the rhs so that output decorations are clamped to
# `min(decoration(arg_i))`.

# Symbolics' `toexpr` resolves call heads to actual function *values* (not
# `Expr(:., Module, QuoteNode(name))`), so these checks compare against the
# function objects directly.

_is_intersect_call(ex) = false
function _is_intersect_call(ex::Expr)
    ex.head === :call || return false
    return ex.args[1] === IntervalArithmetic.intersect_interval
end

_is_reverse_op_call(ex) = false
function _is_reverse_op_call(ex::Expr)
    ex.head === :call || return false
    f = ex.args[1]
    f isa Function || return false
    name = string(nameof(f))
    return startswith(name, "_rev_") &&
           parentmodule(f) === ReversePropagation
end

"""
    preserve_decorations(ex)

Walk `ex` and wrap calls to `IntervalArithmetic.intersect_interval` and
`ReversePropagation._rev_*` so that each output interval's decoration is
clamped to `min(decoration(inputs)...)` instead of being weakened to `trv`.

Called on the body `Expr` returned by
`ReversePropagation.forward_backward_expr` before `@RuntimeGeneratedFunction`.
"""
preserve_decorations(ex) = ex
function preserve_decorations(ex::Expr)
    if ex.head === :(=) && ex.args[2] isa Expr && _is_intersect_call(ex.args[2])
        lhs = ex.args[1]
        call = ex.args[2]
        inputs = Expr(:tuple, call.args[2:end]...)
        new_rhs = :($(preserve_dec_intersect)($call, $inputs))
        return Expr(:(=), lhs, new_rhs)
    elseif ex.head === :(=) && ex.args[2] isa Expr && _is_reverse_op_call(ex.args[2])
        lhs = ex.args[1]
        call = ex.args[2]
        inputs = Expr(:tuple, call.args[2:end]...)
        new_rhs = :($(preserve_dec_reverse)($call, $inputs))
        return Expr(:(=), lhs, new_rhs)
    else
        return Expr(ex.head, map(preserve_decorations, ex.args)...)
    end
end


make_function(ex, vars; exact::Bool = false) = begin
	code = build_function(ex, vars, nanmath=false)
	exact && (code = exactify(code))
	@RuntimeGeneratedFunction(code)
end


"""
Convert inequalities in an expression to interval constraints

Moves everything to one side, e.g.

x^2 < y^2   becomes  x^2 - y^2 ∈ [-Inf, 0]

Returns the new expression and constraint.
"""
function analyse(ex)
	ex2 = value(ex)
	
	op = operation(ex2)
	lhs, rhs = arguments(ex2)

	
	if op ∈ (≤, <)
		constraint = interval(-Inf, 0)
		Num(lhs - rhs), constraint

	elseif op ∈ (≥, >)
		constraint = interval(0, +Inf)
		Num(lhs - rhs), constraint

	elseif op == (==)
		constraint = interval(0, 0)
		Num(lhs - rhs), constraint

	else
		return ex, interval(0, 0)   # implicit 0
	end

end





function separator(ex, vars; exact::Bool = false)
	ex2 = ex

	if ex isa Num
		ex2 = value(ex)
	end

	op = operation(ex2)


	if op == ¬
		arg = arguments(ex2)[1]
		return ¬(separator(arg, vars; exact = exact))
	end

	lhs, rhs = arguments(ex2)

	if op == &
		return separator(lhs, vars; exact = exact) ⊓ separator(rhs, vars; exact = exact)

	elseif op == |
		return separator(lhs, vars; exact = exact) ⊔ separator(rhs, vars; exact = exact)

	elseif op ∈ (≤, <)
		constraint = interval(-Inf, 0)
		Separator(Num(lhs - rhs), vars, constraint; exact = exact)

	elseif op ∈ (≥, >)
		constraint = interval(0, +Inf)
		Separator(Num(lhs - rhs), vars, constraint; exact = exact)

	elseif op == (==)
		constraint = interval(0, 0)
		Separator(Num(lhs - rhs), vars, constraint; exact = exact)

	else
		return Separator(ex, vars, interval(0, 0); exact = exact)   # implicit "== 0"
	end

end


function separator(ex; exact::Bool = false)
	vars = Symbolics.get_variables(ex)


	return separator(ex, vars; exact = exact)
end


const constraint = separator


