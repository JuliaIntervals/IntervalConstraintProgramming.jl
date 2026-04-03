# Future work

## `@constraint` macro for chained comparisons

Julia lowers `0 <= x^2+y^2 <= 1` to `(0 <= x^2+y^2) && (x^2+y^2 <= 1)`, and `&&` requires a `Bool`, so this fails with symbolic expressions.

A `@constraint` macro could intercept the AST before lowering and convert chained comparisons into `&` (which works symbolically) or directly into the `∈` form:

```julia
@constraint 0 <= x^2 + y^2 <= 1    # → x^2+y^2 ∈ interval(0, 1)
@constraint x^2 + y^2 <= 1          # → simple case, works as-is
```

The package already exports `@constraint` but it is not yet defined.

## ReversePropagation method overwrite warnings

ReversePropagation emits many "Method definition overwritten" warnings with Symbolics v7. Harmless but noisy — should be addressed upstream in ReversePropagation.
