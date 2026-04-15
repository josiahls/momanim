from std.testing import TestSuite, assert_equal
from momanim.mobject.geometry import Point2d, Point3d, Vector2d, Vector3d, HalfPlane2d


def test_Point2d() raises:
    var p1 = Point2d(1.0, 2.0)
    var p2 = Point2d(3.0, 4.0)
    # assert_equal(p1 + p2, geometry.Point2d(4.0, 6.0))


def test_HalfPlane2d() raises:
    var p1 = Point2d(0.0, 4.0)
    var p2 = Point2d(8.0, 12.0)
    var v = Vector2d(p1^, p2^)
    var half_plane = HalfPlane2d(v)
    assert_equal(half_plane.i, 8.0)
    assert_equal(half_plane.j, -8.0)
    assert_equal(half_plane.c, 32.0)

    var test_p = Point2d(5.0, 8.0)
    assert_equal(half_plane.point_relative_to_plane(test_p), 8.0)
    var test_p2 = Point2d(0.0, 8.0)
    assert_equal(half_plane.point_relative_to_plane(test_p2), -32.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
