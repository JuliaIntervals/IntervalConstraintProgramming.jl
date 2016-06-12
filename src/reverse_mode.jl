const rev_ops = Dict(
                    :+     => :plusRev,
                    :*     => :mulRev,
                    :^     => :powerRev,
                    :-     => :minusRev,
                    :sqrt  => :sqrtRev
                    )


function plusRev(a::Interval, b::Interval, c::Interval)  # a = b + c
    # a = a ∩ (b + c)
    b = b ∩ (a - c)
    c = c ∩ (a - b)

    return a, b, c
end

plusRev(a,b,c) = plusRev(promote(a,b,c)...)

function minusRev(a::Interval, b::Interval, c::Interval)  # a = b - c
    # a = a ∩ (b - c)
    b = b ∩ (a + c)
    c = c ∩ (b - a)

    return a, b, c
end

minusRev(a,b,c) = minusRev(promote(a,b,c)...)


function mulRev(a::Interval, b::Interval, c::Interval)  # a = b * c
    # a = a ∩ (b * c)
    b = b ∩ (a / c)
    c = c ∩ (a / b)

    return a, b, c
end

mulRev(a,b,c) = mulRev(promote(a,b,c)...)


Base.iseven(x::Interval) = isinteger(x) && iseven(round(Int, x.lo))

function powerRev(a::Interval, b::Interval, c::Interval)  # a = b^c,  log(a) = c.log(b),  b = a^(1/c)

    # special if c is an even integer: include the possibility of the negative root

    if c == 2  # a = b^2
        b1 = b ∩ √a
        b2 = b ∩ (-√a)

        b = hull(b1, b2)

    elseif iseven(c)
        b1 = b ∩ ( a^(inv(c) ))
        b2 = b ∩ ( -( a^(inv(c)) ) )

        b = hull(b1, b2)

    else

        b = b ∩ ( a^(inv(c) ))
    end

    # a = a ∩ (b ^ c)
    c = c ∩ (log(a) / log(b))

    return a, b, c
end

powerRev(a,b,c) = powerRev(promote(a,b,c)...)


function sqrtRev(a::Interval, b::Interval)  # a = sqrt(b)
    # a1 = a ∩ √b
    # a2 = a ∩ (-(√b))
    # a = hull(a1, a2)

    b = b ∩ (a^2)

    return a, b
end

sqrtRev(a,b) = sqrtRev(promote(a,b)...)
