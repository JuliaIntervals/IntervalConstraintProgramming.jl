

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


