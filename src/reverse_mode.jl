export plus_rev, minus_rev, mul_rev,
    power_rev, sqrt_rev, sqr_rev # export due to quoting issue

const rev_ops = Dict(
                    :+     => :plus_rev,
                    :-     => :minus_rev,
                    :*     => :mul_rev,
                    :^     => :power_rev,
                    :sqrt  => :sqrt_rev,
                    :()    => :()
                    )


function plus_rev(a::Interval, b::Interval, c::Interval)  # a = b + c
    # a = a ∩ (b + c)  # add this line for plus contractor (as opposed to reverse function)
    b = b ∩ (a - c)
    c = c ∩ (a - b)

    return a, b, c
end

plus_rev(a,b,c) = plus_rev(promote(a,b,c)...)

function minus_rev(a::Interval, b::Interval, c::Interval)  # a = b - c
    # a = a ∩ (b - c)
    b = b ∩ (a + c)
    c = c ∩ (b - a)

    return a, b, c
end

minus_rev(a,b,c) = minus_rev(promote(a,b,c)...)


function mul_rev(a::Interval, b::Interval, c::Interval)  # a = b * c
    # a = a ∩ (b * c)
    b = b ∩ (a / c)
    c = c ∩ (a / b)

    return a, b, c
end

mul_rev(a,b,c) = mul_rev(promote(a,b,c)...)


Base.iseven(x::Interval) = isinteger(x) && iseven(round(Int, x.lo))

function power_rev(a::Interval, b::Interval, c::Interval)  # a = b^c,  log(a) = c.log(b),  b = a^(1/c)

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

power_rev(a,b,c) = power_rev(promote(a,b,c)...)


function sqrt_rev(a::Interval, b::Interval)  # a = sqrt(b)
    # a1 = a ∩ √b
    # a2 = a ∩ (-(√b))
    # a = hull(a1, a2)

    b = b ∩ (a^2)

    return a, b
end

sqrt_rev(a,b) = sqrt_rev(promote(a,b)...)


# IEEE-1788 style

function sqr_rev(c, x)   # c = x^2;  refine x
    x1 = sqrt(c) ∩ x
    x2 = -(sqrt(c)) ∩ x

    return hull(x1, x2)
end

sqr_rev(c) = sqr_rev(c, -∞..∞)

"""
∘_rev1(b, c, x) is the subset of x such that x ∘ b is defined and in c
∘_rev2(a, c, x) is the subset of x such that a ∘ x is defined and in c

If these agree (∘ is commutative) then call it ∘_rev(b, c, x)
"""

function mul_rev_new(b, c, x)   # c = b*x
    return x ∩ (c / b)
end

function pow_rev1(b, c, x)   # c = x^b
    return x ∩ c^(1/b)
end

function pow_rev2(a, c, x)   # c = a^x
    return x ∩ (log(c) / lob(a))
end
