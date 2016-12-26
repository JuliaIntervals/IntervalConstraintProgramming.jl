using Documenter
using IntervalConstraintProgramming, ValidatedNumerics

makedocs(
    modules = Module[IntervalConstraintProgramming],
    doctest = true,
    format = :html,
    authors = "David P. Sanders",
    sitename = "IntervalConstraintProgramming.jl"
    )

# deploydocs(
#     deps = Deps.pip("pygments", "mkdocs", "mkdocs-cinder", "python-markdown-math"),
#     repo   = "github.com/dpsanders/IntervalConstraintProgramming.jl.git",
#     julia = "0.5",
#     osname = "linux"
# )

deploydocs(
    repo = "github.com/dpsanders/IntervalConstraintProgramming.jl.git",
    #target = "build",
    deps = nothing,
    make = nothing,
    julia = "release",
    osname = "linux"
)
