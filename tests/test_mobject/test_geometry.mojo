from std.testing import TestSuite, assert_equal
from momanim.mobject.geometry import Point2d, Point3d, Vector2d, Vector3d, HalfPlane2d, Triangle2d, Trapezoid2d


def test_Point2d() raises:
    var p1 = Point2d(1.0, 2.0)
    var p2 = Point2d(3.0, 4.0)
    # assert_equal(p1 + p2, geometry.Point2d(4.0, 6.0))


def test_HalfPlane2d() raises:
    var p1 = Point2d(0.0, 4.0)
    var p2 = Point2d(8.0, 12.0)
    var v = Vector2d(p1^, p2^)
    var half_plane = HalfPlane2d(v)
    assert_equal(half_plane.ij, Point2d(8.0, -8.0))
    assert_equal(half_plane.c, 32.0)

    var test_p = Point2d(5.0, 8.0)
    assert_equal(half_plane.point_relative_to_plane(test_p), 8.0)
    var test_p2 = Point2d(0.0, 8.0)
    assert_equal(half_plane.point_relative_to_plane(test_p2), -32.0)
    
    var half_plane2 = HalfPlane2d(Vector2d(Point2d(0.0, 10.0), Point2d(0.0, 4.0)))
    assert_equal(half_plane2.point_relative_to_plane(Point2d(-1.0, 8.0)), 6)

    var half_plane3 = HalfPlane2d(Vector2d(Point2d(8.0, 12.0), Point2d(0.0, 10.0)))
    assert_equal(half_plane3.point_relative_to_plane(Point2d(0.0, 8.0)), -16.0)


def test_Triangle2d() raises:
    var p1 = Point2d(0.0, 4.0)
    var p2 = Point2d(8.0, 12.0)
    var p3 = Point2d(0.0, 10.0)
    var t1 = Triangle2d(p1^, p2^, p3^)
    assert_equal(Point2d(1.0, 9.0) in t1, True)
    assert_equal(Point2d(-1.0, 8.0) in t1, False)


def test_Trapezoid2d() raises:
    var p1 = Point2d(0.0, 4.0)
    var p2 = Point2d(8.0, 12.0)
    var p3 = Point2d(0.0, 10.0)
    var p4 = Point2d(-8.0, 12.0)
    var t1 = Triangle2d(p1.copy(), p2^, p3.copy())
    var t2 = Triangle2d(p1^, p3^, p4^)
    var t = Trapezoid2d(t1^, t2^)
    assert_equal(Point2d(8.0, 7.0) in t, False)
    assert_equal(Point2d(1.0, 8.0) in t, True)
    assert_equal(Point2d(-1, 8) in t, True)
    assert_equal(Point2d(-4, 12) in t, False)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
