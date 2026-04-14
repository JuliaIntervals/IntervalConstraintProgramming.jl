using Documenter
using DocumenterVitepress
using IntervalConstraintProgramming, IntervalArithmetic

makedocs(;
    modules = [IntervalConstraintProgramming],
    authors = "David P. Sanders",
    sitename = "IntervalConstraintProgramming.jl",
    format = DocumenterVitepress.MarkdownVitepress(;
        repo = "github.com/JuliaIntervals/IntervalConstraintProgramming.jl",
        devbranch = "master",
        devurl = "dev",
    ),
    pages = [
        "Home" => "index.md",
        "Contractors and Separators" => "contractors_and_separators.md",
        "Architecture" => "architecture.md",
        "API" => "api.md",
    ],
)

DocumenterVitepress.deploydocs(;
    repo = "github.com/JuliaIntervals/IntervalConstraintProgramming.jl",
    target = joinpath(@__DIR__, "build"),
    branch = "gh-pages",
    devbranch = "master",
    push_preview = true,
)
