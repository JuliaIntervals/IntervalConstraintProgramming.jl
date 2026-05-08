abstract type AbstractContractor end


"""
	Contractor(ex, vars; exact=false, params=[])
	Contractor(ssa::SSAFunction, ex, vars; exact=false, params=[])

HC4Revise forward--backward contractor for the constraint `ex(vars...; params...) ∈ constraint`.

The symbolic expression is first lowered to SSA form via
`ReversePropagation.cse_equations`; the resulting `SSAFunction` is stored on the
contractor so it can be reused (e.g. shared between a `Separator` and other
contractors over the same expression).

If `exact=true`, every numeric literal in the generated forward--backward code
is wrapped in `IntervalArithmetic.exact` (see [`exactify`](@ref)) and every
`intersect_interval` / `_rev_*` call site is wrapped so its output decoration
is `min(decoration(inputs)...)` instead of the IEEE 1788 default `trv` (see
[`preserve_decorations`](@ref)). Together these suppress the "NG" flag and
preserve `com` / `dac` decorations through contraction.

If `params` is non-empty, the contractor compiles a function of the form
`(__inputs, __constraint, __params) -> ...`. At call time, supply `param_vals`
as a positional third argument: `CC(X, constraint, param_vals)`. This lets the
same compiled contractor be re-used at runtime with different parameter values
— useful when a separator must be applied many times with different constants
(e.g. once per blocker disc), avoiding rebuild costs that scale with the number
of distinct parameter values.
"""
struct Contractor{V, E, S, CC, P} <: AbstractContractor
    vars::V
    ex::E
    ssa::S
    contractor::CC
    params::P
end

Contractor(ex, vars; exact::Bool = false, params = []) =
    Contractor(cse_equations(ex), ex, vars; exact = exact, params = params)

Contractor(ssa::SSAFunction, ex, vars; exact::Bool = false, params = []) =
    Contractor(vars, ex, ssa,
               build_fb_contractor(ssa, vars; exact = exact, params = params),
               params)

# Build the forward--backward contractor function. When `exact=false`, just
# forward to RP's `forward_backward_contractor`. When `exact=true`, re-assemble
# the outer wrapper so we can (a) mark every Real literal as
# `IntervalArithmetic.exact` (so constraint literals and CSE-inserted exponents
# don't drag the NG flag through the result) and (b) clamp decorations through
# intersect/reverse-op call sites to `min(input decorations)` instead of the
# IEEE 1788 default `trv` weakening.
#
# `params` (if non-empty) becomes a third positional argument `__params` to
# the generated function — see RP's `forward_backward_contractor` for the
# wiring of the same convention in the non-exact path.
function build_fb_contractor(ssa::SSAFunction, vars; exact::Bool = false, params = [])
    exact || return forward_backward_contractor(ssa, vars, params)

    code, final_var, constraint_var =
        ReversePropagation.forward_backward_expr(ssa, vars, params)

    input_vars = toexpr(Symbolics.MakeTuple(vars))
    final = toexpr(final_var)
    constraint = toexpr(constraint_var)

    body = preserve_decorations(exactify(code))

    if isempty(params)
        function_code = :(
            (__inputs, __constraint) -> begin
                $input_vars = __inputs
                $constraint = __constraint
                $body
                return $input_vars, $(final)
            end
        )
    else
        params_tuple = toexpr(Symbolics.MakeTuple(params))
        function_code = :(
            (__inputs, __constraint, __params) -> begin
                $input_vars = __inputs
                $constraint = __constraint
                $params_tuple = __params
                $body
                return $input_vars, $(final)
            end
        )
    end

    return @RuntimeGeneratedFunction(function_code)
end

(CC::Contractor)(X, constraint=interval(0.0)) = IntervalBox(CC.contractor(X, constraint)[1])
(CC::Contractor)(X, constraint, param_vals::Tuple) = IntervalBox(CC.contractor(X, constraint, param_vals)[1])


abstract type AbstractSeparator end

"A separator models the inside and outside of a constraint set using a forward--backward contractor"
struct Separator{V,E,C,F,R,P} <: AbstractSeparator
    vars::V
    ex::E
    constraint::C
    f::F
    contractor::R
    params::P
end

# Base.show(io::IO, S::Separator) = print(io, "Separator($(S.ex) ∈ $(S.constraint), vars = $(join(S.vars, ", ")))")

function Base.show(io::IO, S::AbstractSeparator)
    if hasproperty(S, :constraint)
        print(io, "Separator($(S.ex) ∈ $(S.constraint), vars=$(join(S.vars, ", ")))")
    else
        print(io, "Separator($(S.ex), vars=$(join(S.vars, ", ")))")
    end
end

function Separator(orig_expr, vars; exact::Bool = false, params = [])
    ex, constraint = analyse(orig_expr)

    return Separator(ex, vars, constraint; exact = exact, params = params)
end

function Separator(ex, vars, constraint::Interval; exact::Bool = false, params = [])
    ssa = cse_equations(ex)
    return Separator(vars, ex, constraint,
                     make_function(ex, vars; exact = exact, params = params),
                     Contractor(ssa, ex, vars; exact = exact, params = params),
                     params)
end

function separate_infinite_box(S::Separator, X::IntervalBox, param_vals=nothing)
    # for an box that extends to infinity we cannot evaluate at a corner
    # so use the old method instead where we do inner and outer contractors separately

    C = S.contractor
    a, b = inf(S.constraint), sup(S.constraint)

    contract = param_vals === nothing ?
        (cset) -> C(X, cset) :
        (cset) -> C(X, cset, param_vals)

    inner = contract(interval(a, b))

    # to compute outer, we contract with respect to the complement of `a..b`:
    local outer
    if a == -Inf
        outer = contract(interval(b, Inf))

    elseif b == Inf
        outer = contract(interval(-Inf, a))

    else
        # the complement is a union of two pieces
        outer1 = contract(interval(-Inf, a))
        outer2 = contract(interval(b, Inf))

        outer = outer1 ⊔ outer2
    end

    boundary = inner ⊓ outer

    return (boundary, inner, outer)
end


"Returns boundary, inner, outer"
(SS::Separator)(X) = _separate(SS, X, nothing)

# Atomic separators that were built with no params silently ignore param_vals,
# so mixed compositions (param + non-param via ⊓/⊔) work without special-casing.
(SS::Separator)(X, param_vals::Tuple) =
    _separate(SS, X, isempty(SS.params) ? nothing : param_vals)

function _separate(SS::Separator, X, param_vals)

    if any(x -> isinf(diam(x)), X)
        return separate_infinite_box(SS, X, param_vals)
    end

    # using the contractor to compute the boundary:
    boundary = param_vals === nothing ?
        SS.contractor(X) :                          # contract w.r.t. 0
        SS.contractor(X, interval(0.0), param_vals)

    # extend the boundary by evaluating at corners of the box to determine inner and outer:

    lb = IntervalBox(inf.(X))
    ub = IntervalBox(sup.(X))

    inner = boundary
    outer = boundary

    eval_at = param_vals === nothing ?
        (corner) -> SS.f(corner) :
        (corner) -> SS.f(corner, param_vals)

    lb_image = eval_at(lb)
    if !isempty_interval(lb_image) && issubset_interval(lb_image, SS.constraint)
        inner = inner ⊔ lb
    else
        outer = outer ⊔ lb
    end

    ub_image = eval_at(ub)
    if !isempty_interval(ub_image) && issubset_interval(ub_image, SS.constraint)
        inner = inner ⊔ ub
    else
        outer = outer ⊔ ub
    end

    return boundary, inner, outer
end
