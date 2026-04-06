from std.testing import TestSuite, assert_equal
from momanim.mobject.bezier_curve import QuadBezierCurve, Point, farin_rational_de_casteljau, farin_rational_de_casteljau_split, farin_rational_de_casteljau_between


def test_QuadBezierCurve_init() raises:
    var curve = QuadBezierCurve(Point(0.0, 0.0), Point(1.0, 1.0))
    assert_equal(curve.points, 
        [
            Point(0.0, 0.0), 
            Point(0.3333333333333333, 0.3333333333333333), 
            Point(0.6666666666666667, 0.6666666666666667), 
            Point(1.0, 1.0), 
    ])

def test_farin_rational_de_casteljauz() raises:
    var curve = QuadBezierCurve(Point(0.0, 0.0), Point(3.0, 3.0))
    var t: Float32 = 0.5
    var result = farin_rational_de_casteljau(curve, t)
    # Cubic collinear controls (0,0)…(3,3): B(0.5) is midpoint of chord (1.5, 1.5).
    assert_equal(result, Point(1.5, 1.5))


def test_farin_rational_de_casteljau_split() raises:
    var curve = QuadBezierCurve(Point(0.0, 0.0), Point(1.0, 1.0))
    var t: Float32 = 0.5
    var splits = farin_rational_de_casteljau_split(curve, t)
    # Collinear cubic; t=0.5: left [P0,L0,Q0,C], right [C,Q1,L2,P3].
    assert_equal(
        splits[0].points,
        [
            Point(0.0, 0.0),
            Point(0.16666666666666666, 0.16666666666666666),
            Point(0.3333333333333333, 0.3333333333333333),
            Point(0.5, 0.5),
        ],
    )
    assert_equal(
        splits[1].points,
        [
            Point(0.5, 0.5),
            Point(0.6666666666666667, 0.6666666666666667),
            Point(0.8333333333333334, 0.8333333333333334),
            Point(1.0, 1.0),
        ],
    )

def test_farin_rational_de_casteljau_between() raises:
    var curve = QuadBezierCurve(Point(0.0, 0.0), Point(1.0, 1.0))
    var a: Float32 = 0.5
    var b: Float32 = 0.75

    var between_curve = farin_rational_de_casteljau_between(curve, a, b)
    # Collinear cubic; t=0.5: left [P0,L0,Q0,C], right [C,Q1,L2,P3].
    assert_equal(
        between_curve.points,
        [
            Point(0.5, 0.5),
            Point(0.5833333333333334, 0.5833333333333334),
            Point(0.6666666666666667, 0.6666666666666667),
            Point(0.75, 0.75),
        ],
    )

    var curve2 = QuadBezierCurve(
        Point(-10.0, 0.0, 10.0),
        Point(-6.666667, 3.3333333, 10.0),
        Point(-3.3333333, 6.666667, 10.0),
        Point(0.0, 10.0, 10.0),
    )
    var a2: Float32 = 0
    var b2: Float32 = 1
    var between_curve2 = farin_rational_de_casteljau_between(curve2, a2, b2)
    assert_equal(
        between_curve2.points,
        [
            Point(-10.0, 0.0, 10.0),
            Point(-6.666667, 3.3333333, 10.0),
            Point(-3.3333333, 6.666667, 10.0),
            Point(0.0, 10.0, 10.0),
        ],
    )






def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
