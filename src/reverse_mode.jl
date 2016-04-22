function plusRev(a::Interval, b::Interval, c::Interval)  # a = b + c
    a = a ∩ (b + c)
    b = b ∩ (a - c)
    c = c ∩ (a - b)

    a, b, c
end

plusRev(a,b,c) = plusRev(promote(a,b,c)...)

function minusRev(a::Interval, b::Interval, c::Interval)  # a = b - c
    a = a ∩ (b - c)
    b = b ∩ (a + c)
    c = c ∩ (b - a)

    a, b, c
end

minusRev(a,b,c) = minusRev(promote(a,b,c)...)


function mulRev(a::Interval, b::Interval, c::Interval)  # a = b * c
    a = a ∩ (b * c)
    b = b ∩ (a / c)
    c = c ∩ (a / b)

    a, b, c
end

mulRev(a,b,c) = mulRev(promote(a,b,c)...)


function powerRev(a::Interval, b::Interval, c::Interval)  # a = b^c,  log(a) = c.log(b),  b = a^(1/c)

    # special if c is an even integer: include the possibility of the negative root

    if c == 2  # a = b^2
        b1 = b ∩ √a
        b2 = b ∩ (-√a)

        b = hull(b1, b2)
    else
        b = b ∩ ( a^(inv(c) ))
    end

    a = a ∩ (b ^ c)
    c = c ∩ (log(a) / log(b))

    a, b, c
end

powerRev(a,b,c) = powerRev(promote(a,b,c)...)
