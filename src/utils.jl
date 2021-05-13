

make_function(ex, vars) = eval(build_function(ex, vars))


"""
Convert inequalities in an expression to interval constraints

Moves everything to one side, e.g.

x^2 < y^2   becomes  x^2 - y^2 ∈ [-∞, 0]

Returns the new expression and constraint.
"""
function analyse(ex)
	ex2 = value(ex)
	
	op = operation(ex2)
	lhs, rhs = arguments(ex2)

	
	if op ∈ (≤, <)
		constraint = interval(-∞, 0)
		Num(lhs - rhs), constraint
		
	elseif op ∈ (≥, >)
		constraint = interval(0, +∞)
		Num(lhs - rhs), constraint
		
	elseif op == (==)
		constraint = interval(0, 0)
		Num(lhs - rhs), constraint
	
	else
		return ex, interval(0, 0)   # implicit 0
	end
		
end





function separator(ex, vars)
	ex2 = ex 

	if ex isa Num
		ex2 = value(ex)
	end
	
	op = operation(ex2)


	if op == ¬
		arg = arguments(ex2)[1]
		return ¬(separator(arg, vars))
	end

	lhs, rhs = arguments(ex2)

	if op == &
		return separator(lhs, vars) ∩ separator(rhs, vars)

	elseif op == |
		return separator(lhs, vars) ∪ separator(rhs, vars)
	
	elseif op ∈ (≤, <)
		constraint = interval(-∞, 0)
		Separator(Num(lhs - rhs), vars, constraint)
		
	elseif op ∈ (≥, >)
		constraint = interval(0, +∞)
		Separator(Num(lhs - rhs), vars, constraint)
		
	elseif op == (==)
		constraint = interval(0, 0)
		Separator(Num(lhs - rhs), vars, constraint)
	
	else
		return Separator(ex, vars, interval(0, 0))   # implicit "== 0"
	end
		
end


function separator(ex)
	vars = Symbolics.get_variables(ex)


	return separator(ex, vars)
end


const constraint = separator


