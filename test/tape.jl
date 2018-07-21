
struct TapeTester{T}
    f::Function
    X::Vector{Interval{T}}
    constraint::Interval{T}
    contraction::Vector{Interval{T}}
end


@testset "Tape Tests" begin
    tests = TapeTester{Float64}[]
    push!(tests, TapeTester(X->X[1]*exp(X[2]) + sin(X[3]), [-4.. -3, -1.5..0.5, -4.. 0], 0..0, [-3.4.. -3, -1.5.. 0.5, -4.. -3.8]))
    push!(tests, TapeTester(X->(2..2) * X[1], [-100..100, -100..100], 0..0, [0..0, -100..100]))
    push!(tests, TapeTester(X->X[1]^2 + X[2]^2, [-100..100, -100..100], -∞..1, [-1..1, -1..1]))
    push!(tests, TapeTester(X->2^X[2] - X[1], [-10..10, -10..10], 0..0, [0..10, -10..3.33]))
    push!(tests, TapeTester(X->X[1] * X[2] - X[3], [1..4, 1..4, 8..40], 0..0, [2..4, 2..4, 8..16]))

    for i in 1:length(tests)
            @test all(icp(tests[i].f, tests[i].X, tests[i].constraint) .∈ tests[i].contraction)
    end
end
