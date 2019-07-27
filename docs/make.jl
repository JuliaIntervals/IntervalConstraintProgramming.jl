using Documenter
using IntervalConstraintProgramming, IntervalArithmetic

makedocs(
    modules = [IntervalConstraintProgramming],
    doctest = true,
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    authors = "David P. Sanders",
    sitename = "IntervalConstraintProgramming.jl",

    pages = Any[
        "Home" => "index.md",
        "API" => "api.md"
    ]
    )

deploydocs(
    repo = "github.com/JuliaIntervals/IntervalConstraintProgramming.jl.git",
    target = "build",
    deps = nothing,
    make = nothing,
)
