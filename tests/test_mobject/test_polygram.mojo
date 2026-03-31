from std.testing import TestSuite, assert_equal
from momanim.mobject.polygram import Point, Vector, Square
from std.math import sqrt


def test_Point_hypot() raises:
    assert_equal(Point(0.0, 0.0).hypot(Point(1.0, 0.0)), 1.0)
    assert_equal(Point(5.0, 0.0).hypot(Point(10.0, 0.0)), 5.0)
    assert_equal(Point(5.0, 5.0).hypot(Point(10.0, 10.0)), 5.0 * sqrt(Float32(2.0)))


def test_Vector_hypot() raises:
    assert_equal(Vector(Point(0.0, 0.0), Point(1.0, 0.0)).hypot(), 1.0)
    assert_equal(Vector(Point(5.0, 0.0), Point(10.0, 0.0)).hypot(), 5.0)
    assert_equal(Vector(Point(5.0, 5.0), Point(10.0, 10.0)).hypot(), 5.0 * sqrt(Float32(2.0)))

    var vector: Vector = Vector([0.0, 0.0, 0.0], [1.0, 0.0, 0.0])
    assert_equal(vector.hypot(), 1.0)
    var vector2: Vector = Vector([5.0, 0.0, 0.0], [10.0, 0.0, 0.0])
    assert_equal(vector2.hypot(), 5.0)
    var vector3: Vector = Vector([5.0, 5.0, 0.0], [10.0, 10.0, 0.0])
    assert_equal(vector3.hypot(), 5.0 * sqrt(Float32(2.0)))

    var vector4 = Vector([-1.0, -1.0], [1.0, -1.0])
    assert_equal(vector4.p0(), Point(-1.0, -1.0, 1.0))



def test_Square_init() raises:
    var square = Square(color_fill=SIMD[DType.uint8, 4](255, 255, 255, 255))
    assert_equal(
        square.load(), 
        SIMD[DType.float32, 24](
            -1.0, -1.0, 1.0,  1.0, -1.0, 1.0, 
             1.0, -1.0, 1.0,  1.0,  1.0, 1.0, 
             1.0,  1.0, 1.0, -1.0,  1.0, 1.0, 
            -1.0,  1.0, 1.0, -1.0, -1.0, 1.0
        ))
    assert_equal(square.color_fill, SIMD[DType.uint8, 4](255, 255, 255, 255))

    var square2 = Square(
        v0=Vector([-1.0, -1.0, 1.0], [1.0, -1.0, 1.0]),
        v1=Vector([1.0,  -1.0, 1.0], [1.0,  1.0, 1.0]),
        v2=Vector([1.0,  1.0, 1.0], [-1.0,  1.0, 1.0]),
        v3=Vector([-1.0,  1.0, 1.0], [-1.0, -1.0, 1.0]),
        color_fill=SIMD[DType.uint8, 4](255, 255, 255, 255)
    )
    assert_equal(square2.vertices[], square.vertices[])
    assert_equal(square2.color_fill, square.color_fill)

def test_Square_draw_fn() raises:
    var square = Square(color_fill=SIMD[DType.uint8, 4](255, 255, 255, 255))
    var draw_fn = square.draw_fn()
    # Compare coordinates: Point equality is not value-based (distinct allocations).
    assert_equal(draw_fn(0.0).load(), Point(-1.0, -1.0).load())
    assert_equal(draw_fn(0.25).load(), Point(1.0, -1.0).load())
    assert_equal(draw_fn(0.5).load(), Point(1.0, 1.0).load())
    assert_equal(draw_fn(0.75).load(), Point(-1.0, 1.0).load())
    assert_equal(draw_fn(1.0).load(), Point(-1.0, -1.0).load())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
