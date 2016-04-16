# `ConstraintPropagation.jl`

- `d = Domain()`:  creates a new `Domain` object, representing a domain defined by (in)equality constraints

- `add_constraint(d, ex::Expr)`:  adds a constraint to the Domain object

- `initialize(d)`:  initializes a number of interval variables equal to the total number of variables used in all the constraints

- `apply_contractor(d, i)`  applies the contractor corresponding to the ith constraint.


```julia
julia> d = Domain()
Domain(0,Expr[],Function[],Array{Int64,1}[],Dict{Symbol,Int64}(),ValidatedNumerics.Interval{Float64}[])

julia> add_constraint(d, :(x>=0.1));
julia> add_constraint(d, :( (0.5x)^2+y^2 <= 1 ));
julia> add_constraint(d, :(y <= 0.9));

julia> initialize(d)
2-element Array{ValidatedNumerics.Interval{Float64},1}:
 [-∞, ∞]
 [-∞, ∞]

julia> apply_contractor(d,2)
2-element Array{ValidatedNumerics.Interval{Float64},1}:
 [0.0, 2.0]
 [0.0, 1.0]

julia> apply_contractor(d,1)
1-element Array{ValidatedNumerics.Interval{Float64},1}:
 [0.09999999999999999, 2.0]

julia> apply_contractor(d,3)
1-element Array{ValidatedNumerics.Interval{Float64},1}:
 [0.0, 0.9]

julia> d
Domain(2,[:(x >= 0.1),:((0.5x) ^ 2 + y ^ 2 <= 1),:(y <= 0.9)],[(anonymous function),(anonymous function),(anonymous function)],[[1],[1,2],[2]],Dict(:y=>2,:x=>1),ValidatedNumerics.Interval{Float64}[[0.09999999999999999, 2.0],[0.0, 0.9]])

julia> d.variables
2-element Array{ValidatedNumerics.Interval{Float64},1}:
 [0.09999999999999999, 2.0]
 [0.0, 0.9]
```

