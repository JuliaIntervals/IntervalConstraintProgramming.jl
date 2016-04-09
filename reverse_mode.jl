function plusRev(a, b, c)  # a = b + c
    a = a ∩ (b + c)
    b = b ∩ (a - c)
    c = c ∩ (a - b)

    a, b, c
end

function minusRev(a, b, c)  # a = b - c
    a = a ∩ (b - c)
    b = b ∩ (a + c)
    c = c ∩ (b - a)

    a, b, c
end

function mulRev(a, b, c)  # a = b * c
    a = a ∩ (b * c)
    b = b ∩ (a / c)
    c = c ∩ (a / b)

    a, b, c
end

function powerRev(a, b, c)  # a = b^c,  log(a) = c.log(b),  b = a^(1/c)

    # special if c is an even integer: include the possibility of the negative root
    a = a ∩ (b ^ c)
    b = b ∩ ( a^(inv(c) ))
    c = c ∩ (log(a) / log(b))

    a, b, c
end
