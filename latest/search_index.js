var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#IntervalConstraintProgramming.jl-1",
    "page": "Home",
    "title": "IntervalConstraintProgramming.jl",
    "category": "section",
    "text": "This Julia package allows you to specify a set of constraints on real-valued variables, given by (in)equalities, and rigorously calculate inner and outer approximations to the feasible set, i.e. the set that satisfies the constraints.This uses interval arithmetic provided by the author's ValidatedNumerics.jl package, in particular multi-dimensional IntervalBoxes, i.e. Cartesian products of one-dimensional intervals.To do this, interval constraint programming is used, in particular the so-called \"forward–backward contractor\". This is implemented in terms of separators; see [Jaulin & Desrochers].DocTestSetup = quote\n    using IntervalConstraintProgramming, ValidatedNumerics\nend"
},

{
    "location": "index.html#Usage-1",
    "page": "Home",
    "title": "Usage",
    "category": "section",
    "text": "Let's define a constraint, using the @constraint macro:julia> using IntervalConstraintProgramming, ValidatedNumerics\n\njulia> S = @constraint x^2 + y^2 <= 1\nSeparator:\n- variables: x, y\n- expression: x ^ 2 + y ^ 2 ∈ [-∞, 1]It works out automatically that x and y are variables. The macro creates a Separator object, in this case a ConstraintSeparator.We now create an initial interval box in the x–y plane:julia> x = y = -100..100   # notation for creating an interval with `ValidatedNumerics.jl`\n\njulia> X = IntervalBox(x, y)The @constraint macro defines an object S, of type Separator. This is a function which, when applied to the box X = x times y in the x–y plane, applies two contractors, an inner one and an outer one.The inner contractor tries to shrink down, or contract, the box, to the smallest subbox of X that contains the part of X that satisfies the constraint; the outer contractor tries to contract X to the smallest subbox that contains the region where the constraint is not satisfied.When S is applied to the box X, it returns the result of the inner and outer contractors:julia> inner, outer = S(X);\n\njulia> inner\n([-1, 1],[-1, 1])\n\njulia> outer\n([-100, 100],[-100, 100])"
},

{
    "location": "index.html#Set-inversion:-finding-the-feasible-set-1",
    "page": "Home",
    "title": "Set inversion: finding the feasible set",
    "category": "section",
    "text": "To make progress, we must recursively bisect and apply the contractors, keeping track of the region proved to be inside the feasible set, and the region that is on the boundary (\"both inside and outside\"). This is done by the pave function, that takes a separator, a domain to search inside, and an optional tolerance:julia> using Plots\n\njulia> x = y = -100..100\n\njulia> S = @constraint 1 <= x^2 + y^2 <= 3\n\njulia> paving = pave(S, X, 0.125);pave returns an object of type Paving. This contains: the separator itself; an inner approximation, of type SubPaving, which is an alias for a Vector of IntervalBoxes; a SubPaving representing the boxes on the boundary that could not be assigned either to the inside or outside of the set; and the tolerance.We may draw the result using a plot recipe from ValidatedNumerics. Either a single IntervalBox, or a Vector of IntervalBoxes (which a SubPaving is) maybe be drawn using plot from Plots.jl:julia> plot(paving.inner, c=\"green\")\njulia> plot!(paving.boundary, c=\"gray\")The output should look something like this:(Image: Ring)The green boxes have been rigorously proved to be contained within the feasible set, and the white boxes to be outside the set. The grey boxes show those that lie on the boundary, whose status is unknown."
},

{
    "location": "index.html#D-1",
    "page": "Home",
    "title": "3D",
    "category": "section",
    "text": "The package works in any number of dimensions, although it suffers from the usual exponential slowdown in higher dimensions (\"combinatorial explosion\"); in 3D, it is still relatively fast.There are sample 3D calculations in the examples directory, in particular in the solid torus notebook, which uses GLVisualize.gl to provide an interactive visualization that may be rotated and zoomed. The output for the solid torus looks like this:(Image: Coloured solid torus)"
},

{
    "location": "index.html#Set-operations-1",
    "page": "Home",
    "title": "Set operations",
    "category": "section",
    "text": "Separators may be combined using the operators ! (complement), ∩ and ∪ to make more complicated sets; see the notebook for several examples."
},

{
    "location": "index.html#Author-1",
    "page": "Home",
    "title": "Author",
    "category": "section",
    "text": "David P. Sanders\nJulia lab, MIT\nDepartamento de Física, Facultad de Ciencias, Universidad Nacional Autónoma de México (UNAM)"
},

{
    "location": "index.html#References:-1",
    "page": "Home",
    "title": "References:",
    "category": "section",
    "text": "Applied Interval Analysis, Luc Jaulin, Michel Kieffer, Olivier Didrit, Eric Walter (2001)\nIntroduction to the Algebra of Separators with Application to Path Planning, Luc Jaulin and Benoît Desrochers, Engineering Applications of Artificial Intelligence 33, 141–147 (2014)"
},

{
    "location": "index.html#Acknowledements-1",
    "page": "Home",
    "title": "Acknowledements",
    "category": "section",
    "text": "Financial support is acknowledged from DGAPA-UNAM PAPIME grants PE-105911 and PE-107114, and DGAPA-UNAM PAPIIT grant IN-117214, and from a CONACYT-Mexico sabbatical fellowship. The author thanks Alan Edelman and the Julia group for hospitality during his sabbatical visit. He also thanks Luc Jaulin and Jordan Ninin for the IAMOOC online course, which introduced him to this subject."
},

{
    "location": "api.html#",
    "page": "API",
    "title": "API",
    "category": "page",
    "text": ""
},

{
    "location": "api.html#IntervalConstraintProgramming.Vol",
    "page": "API",
    "title": "IntervalConstraintProgramming.Vol",
    "category": "Type",
    "text": "N-dimensional Volume with lower and upper bounds\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.pave",
    "page": "API",
    "title": "IntervalConstraintProgramming.pave",
    "category": "Function",
    "text": "pave(S::Separator, domain::IntervalBox, eps)`\n\nFind the subset of domain defined by the constraints specified by the separator S. Returns (sub)pavings inner and boundary, i.e. lists of IntervalBox.\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.pave-Tuple{IntervalConstraintProgramming.Separator,Array{ValidatedNumerics.IntervalBox{N,T},1},Any}",
    "page": "API",
    "title": "IntervalConstraintProgramming.pave",
    "category": "Method",
    "text": "pave takes the given working list of boxes and splits them into inner and boundary lists with the given separator\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.refine!",
    "page": "API",
    "title": "IntervalConstraintProgramming.refine!",
    "category": "Function",
    "text": "Refine a paving to tolerance ϵ\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.CombinationSeparator",
    "page": "API",
    "title": "IntervalConstraintProgramming.CombinationSeparator",
    "category": "Type",
    "text": "CombinationSeparator is a separator that is a combination (union, intersection, or complement) of other separators.\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.ConstraintFunction",
    "page": "API",
    "title": "IntervalConstraintProgramming.ConstraintFunction",
    "category": "Type",
    "text": "A ConstraintFunction contains the created forward and backward code\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.ConstraintSeparator",
    "page": "API",
    "title": "IntervalConstraintProgramming.ConstraintSeparator",
    "category": "Type",
    "text": "ConstraintSeparator is a separator that represents a constraint defined directly using @constraint.\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.Contractor",
    "page": "API",
    "title": "IntervalConstraintProgramming.Contractor",
    "category": "Type",
    "text": "Contractor represents a Contractor from mathbbR^N to mathbbR^N. Nout is the output dimension of the forward part.\n\n\n\n"
},

{
    "location": "api.html#Base.:∩-Tuple{IntervalConstraintProgramming.Separator,IntervalConstraintProgramming.Separator}",
    "page": "API",
    "title": "Base.:∩",
    "category": "Method",
    "text": "∩(S1::Separator, S2::Separator)\n\nSeparator for the intersection of two sets given by the separators S1 and S2. Takes an iterator of intervals (IntervalBox, tuple, array, etc.), of length equal to the total number of variables in S1 and S2; it returns inner and outer tuples of the same length\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.flatten!-Tuple{IntervalConstraintProgramming.FlatAST,Any}",
    "page": "API",
    "title": "IntervalConstraintProgramming.flatten!",
    "category": "Method",
    "text": "flatten! recursively converts a Julia expression into a \"flat\" (one-dimensional) structure, stored in a FlatAST object. This is close to SSA (single-assignment form, https://en.wikipedia.org/wiki/Static_single_assignment_form).\n\nVariables that are found are considered input_variables. Generated variables introduced at intermediate nodes are stored in intermediate. Returns the variable at the top of the current piece of the tree.\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.isuniqued-Tuple{Symbol}",
    "page": "API",
    "title": "IntervalConstraintProgramming.isuniqued",
    "category": "Method",
    "text": "Check if a symbol like :a has been uniqued to :_a_1_\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.make_forward_function-Tuple{Any,Any,Any,Any}",
    "page": "API",
    "title": "IntervalConstraintProgramming.make_forward_function",
    "category": "Method",
    "text": "Generate code for an anonymous function with given input arguments, output arguments, and code block.\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.make_symbol",
    "page": "API",
    "title": "IntervalConstraintProgramming.make_symbol",
    "category": "Function",
    "text": "Return a new, unique symbol like _z3_\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.mul_rev_new-Tuple{Any,Any,Any}",
    "page": "API",
    "title": "IntervalConstraintProgramming.mul_rev_new",
    "category": "Method",
    "text": "∘_rev1(b, c, x) is the subset of x such that x ∘ b is defined and in c ∘_rev2(a, c, x) is the subset of x such that a ∘ x is defined and in c\n\nIf these agree (∘ is commutative) then call it ∘_rev(b, c, x)\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.parse_comparison-Tuple{Any}",
    "page": "API",
    "title": "IntervalConstraintProgramming.parse_comparison",
    "category": "Method",
    "text": "parse_comparison parses comparisons like x >= 10 into the corresponding interval, expressed as x ∈ [10,∞]\n\nReturns the expression and the constraint interval\n\nTODO: Allow something like [3,4]' for the complement of [3,4]\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.process_assignment!-Tuple{IntervalConstraintProgramming.FlatAST,Any}",
    "page": "API",
    "title": "IntervalConstraintProgramming.process_assignment!",
    "category": "Method",
    "text": "An assigment is of the form a = f(...). The name a is currently retained. TODO: It should later be made unique.\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.process_block!-Tuple{IntervalConstraintProgramming.FlatAST,Any}",
    "page": "API",
    "title": "IntervalConstraintProgramming.process_block!",
    "category": "Method",
    "text": "A block represents a linear sequence of Julia statements. They are processed in order.\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.process_call!",
    "page": "API",
    "title": "IntervalConstraintProgramming.process_call!",
    "category": "Function",
    "text": "A call is something like +(x, y). A new variable is introduced for the result; its name can be specified     using the new_var optional argument. If none is given, then a new, generated     name is used.\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.process_iterated_function!-Tuple{IntervalConstraintProgramming.FlatAST,Any}",
    "page": "API",
    "title": "IntervalConstraintProgramming.process_iterated_function!",
    "category": "Method",
    "text": "Processes something of the form (f↑4)(x) (write as \\uparrow<TAB>) by rewriting it to the equivalent set of iterated functions\n\n\n\n"
},

{
    "location": "api.html#IntervalConstraintProgramming.unify_variables-Tuple{Any,Any}",
    "page": "API",
    "title": "IntervalConstraintProgramming.unify_variables",
    "category": "Method",
    "text": "Unify the variables of two separators\n\n\n\n"
},

{
    "location": "api.html#API-1",
    "page": "API",
    "title": "API",
    "category": "section",
    "text": "Modules = [IntervalConstraintProgramming]\nOrder   = [:type, :function]"
},

]}
