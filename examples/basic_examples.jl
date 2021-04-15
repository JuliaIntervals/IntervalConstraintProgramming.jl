using Revise
using IntervalConstraintProgramming
using Symbolics
using IntervalArithmetic

IntervalArithmetic.configure!(directed_rounding=:fast, powers=:fast)

vars = @variables x, y

ex = x^2 + y^2 ≤ 1
@time S1 = Separator(ex, vars);

X = IntervalBox(-10..10, 2)
S1(X)

using BenchmarkTools

@btime $S1($X)



const plot_options = Dict(:ratio=>1, :leg=>false, :alpha=>0.5, :size=>(500, 300), :lw=>0.3)

function plot_paving!(p; kw...)
    inner, boundary = p

    plot!(inner; plot_options..., kw...)
    plot!(boundary; plot_options..., kw...)
end


using Plots

ex2 = (x - 0.5)^2 + (y - 0.5)^2 <= 1

S2 = Separator(ex2, vars)


p1 = pave(X, S1, 0.1)
p2 = pave(X, S2, 0.1)


S = S1 ∩ S2

p3 = pave(X, S, 0.1)

X

S(X)

S1(X)


S.ex


p = plot(; plot_options...)

plot_paving!(p1, lw=0)
plot_paving!(p2, lw=0)
plot_paving!(p3)

p4 = pave(IntervalBox(-3..3, 2), !(S), 0.1)

plot_paving!(p4; plot_options...)

typeof(S)

# SS = S1 ∩ (!S2);

SS = setdiff(S1, S2);


SS

p5 = pave(IntervalBox(-3..3, 2), SS, 0.1)

p = plot(; plot_options...)
plot_paving!(p5, lw=0)


SS = setdiff(S1, S2);


SS2 = symdiff(S1, S2)

p6 = pave(IntervalBox(-3..3, 2), SS2, 0.01)

p = plot(; plot_options...)
plot_paving!(p6, lw=0)

SS2