immutable ForwardOptimize{F}
    f::F
end

@inline ForwardOptimize(f::ForwardOptimize) = f

for (M, f, arity) in FUNCTIONS
    if arity == 1
        @eval @inline $M.$(f)(t::TrackedReal) = ForwardOptimize($f)(t)
    elseif arity == 2
        @eval @inline $M.$(f)(a::TrackedReal, b::TrackedReal) = ForwardOptimize($f)(a, b)
        for R in REAL_TYPES
            @eval begin
                @inline $M.$(f)(a::TrackedReal, b::$R) = ForwardOptimize($f)(a, b)
                @inline $M.$(f)(a::$R, b::TrackedReal) = ForwardOptimize($f)(a, b)
            end
        end
    end
end

@inline function (self::ForwardOptimize{F}){F,T}(t::TrackedReal{T}) #Define tracked operations for unary functions
    result = self.f(value(t))
    tp = tape(t)
    out = track(result, T, tp)
    cache = IntervalArithmetic.entireinterval()
    record!(tp, ScalarInstruction, self.f, t, out, cache)
    return out
end

@inline function (self::ForwardOptimize{F}){F,V1,V2}(a::TrackedReal{V1}, b::TrackedReal{V2}) #Define tracked operations for binary functions
    T = promote_type(V1, V2)
    result = self.f(value(a), value(b))
    tp = tape(a, b)
    out = track(result, T, tp)
    cache = IntervalArithmetic.entireinterval()
    record!(tp, ScalarInstruction, self.f, (a, b), out, cache)
    return out
end

@inline function (self::ForwardOptimize{F}){F,V}(x::Real, t::TrackedReal{V}) #Define tracked operations for binary functions
    T = promote_type(typeof(x), V)
    result = self.f(x, value(t))
    tp = tape(t)
    out = track(result, T, tp)
    cache = IntervalArithmetic.entireinterval()
    record!(tp, ScalarInstruction, self.f, (x, t), out, cache)
    return out
end

@inline function (self::ForwardOptimize{F}){F,V}(t::TrackedReal{V}, x::Real) #Define tracked operations for binary functions
    T = promote_type(typeof(x), V)
    result = self.f(value(t), x)
    tp = tape(t)
    out = track(result, T, tp)
    cache = IntervalArithmetic.entireinterval()
    record!(tp, ScalarInstruction, self.f, (t, x), out, cache)
    return out
end

mul_rev_1(b, c, x) = mul_rev_IEEE1788(c, b, x)

mul_rev_2(b, c, x) = mul_rev_1(b, x, c)
