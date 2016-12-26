# Example of robot kinematics constraints reported by John Gustafson
# http://www.johngustafson.net/presentations/Multicore2016-JLG.pdf

using ConstraintPropagation

d = Domain()

@add_constraint d s2*c5*s6 - s3*c5*s6 - s4*c5*s6 + c2*c6 + c3*c6 + c4*c6 == 0.4077
@add_constraint d c1*c2*s5 + c1*c3*s5 + c1*c4*s5 + s1*c5 == 1.9115
@add_constraint d s2*s5 + s3*s5 + s4*s5 == 1.9791
@add_constraint d c1*c2 + c1*c3 + c1*c4 + c1*c2 + c1*c3 + c1*c2 == 4.0616
@add_constraint d s1*c2 + s1*c3 + s1*c4 + s1*c2 + s1*c3 + s1*c3 == 1.7172
@add_constraint d s2 + s3 + s4 + s2 + s3 + s2 == 3.9701
@add_constraint d s1^2 + c1^2 == 1
@add_constraint d s2^2 + c2^2 == 1
@add_constraint d s3^2 + c3^2 == 1
@add_constraint d s4^2 + c4^2 == 1
@add_constraint d s5^2 + c5^2 == 1
@add_constraint d s6^2 + c6^2 == 1
