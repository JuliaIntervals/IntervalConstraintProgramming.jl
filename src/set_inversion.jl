

function bisect(X::Interval)
    m = mid(X)
    return [Interval(X.lo, m), Interval(m, X.hi)]
end


function bisect(X::IntervalBox)
    i = findmax([diam(x) for x in X])[2]  # find largest

    x1, x2 = bisect(X[i])

    # the following is ugly -- replace by iterators once https://github.com/JuliaLang/julia/pull/15516
    # has landed?
    X1 = tuple(X[1:i-1]..., x1, X[i+1:end]...)  # insert x1 in i'th place
    X2 = tuple(X[1:i-1]..., x2, X[i+1:end]...)

    return [X1, X2]
end
