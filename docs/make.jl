using Documenter
using IntervalConstraintProgramming, ValidatedNumerics

makedocs(
    modules = Module[IntervalConstraintProgramming],
    doctest = true,
    format = :html,
    sitename = "IntervalConstraintProgramming.jl"
    )

deploydocs(
    #deps = Deps.pip("pygments", "mkdocs", "mkdocs-cinder", "python-markdown-math"),
    repo   = "github.com/dpsanders/IntervalConstraintProgramming.jl.git",
    julia = "0.5",
    #osname = "linux"
)
