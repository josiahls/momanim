from std.testing import (
    TestSuite, 
    assert_equal, 
    assert_not_equal, 
    assert_true, 
    assert_false
)
from std.math import floor

from momanim.rasterization.geometry_2d import FixedPoint2d, FixedPointEdge2d, Point2d
from momanim.rasterization.walkers import Edge2dWalker
from momanim.rasterization.subpixel_sampling import YPixelSampling
from momanim.rasterization.fixed_dtype import FixedInt

def test_Edge2dWalker_q1() raises:
    var edge = FixedPointEdge2d(0, 0, 10, 10)
    
    var w = Edge2dWalker(edge)
    assert_equal(w.x, 0)
    assert_equal(w.dy, 655360)
    assert_equal(w.x_per_unit_dy, 1)
    assert_equal(w.x_remainder, 0)
    # Initial -10 (full dy diff) bias to trigger x step.
    assert_equal(w.error, -655360)

    assert_equal(w.error_step, 0)
    assert_equal(w.step_x, 4369)

    assert_equal(w.error_remainder_step, 0)
    assert_equal(w.step_x_remainder, 4370)


def test_Edge2dWalker_q1_0_0_10_5() raises:
    "Walk along a half y slope."
    var edge = FixedPointEdge2d(0, 0, 10, 5)
    
    var w = Edge2dWalker(edge)
    assert_equal(w.x, 0)
    assert_equal(w.dy, 327680)
    assert_equal(w.x_per_unit_dy, 2)
    assert_equal(w.x_remainder, 0)
    # Initial -10 (full dy diff) bias to trigger x step.
    assert_equal(w.error, -327680)

    assert_equal(w.error_step, 0)
    assert_equal(w.step_x, 8738)

    assert_equal(w.error_remainder_step, 0)
    assert_equal(w.step_x_remainder, 8740)


def test_Edge2dWalker_q1_0_0_10_10_y_start() raises:
    "Walk along a half y slope."
    var edge = FixedPointEdge2d(0, 0, 10, 10)
    
    var w = Edge2dWalker(edge, FixedInt(5))
    assert_equal(w.x, 327680)
    assert_equal(w.dy, 655360)
    assert_equal(w.x_per_unit_dy, 1)
    assert_equal(w.x_remainder, 0)
    # Initial -10 (full dy diff) bias to trigger x step.
    assert_equal(w.error, -655360)

    assert_equal(w.error_step, 0)
    assert_equal(w.step_x, 4369)

    assert_equal(w.error_remainder_step, 0)
    assert_equal(w.step_x_remainder, 4370)


def test_Edge2dWalker_q1_0_0_10_3() raises:
    "Walk along a third y slope. Results in sub pixel error."
    var edge = FixedPointEdge2d(0, 0, 10, 3)
    
    var w = Edge2dWalker(edge)
    assert_equal(w.x, 0)
    assert_equal(w.dy, 196608)
    assert_equal(w.x_per_unit_dy, 3)
    # This case there is a whole pixel remaining. x_remainder, is the total
    # subpixel units of that 1 pixel.
    assert_equal(w.x_remainder, 65536)
    # Initial -10 (full dy diff) bias to trigger x step.
    assert_equal(w.error, -196608)

    # Calculation of regular y sample row steps:
    # In this tests's case, we want to spread `65536` across this and or trigger
    # an x increment.
    # error_step starts with:
    # dy = 196,608 total y units the line traverses
    # error_remainder = 4369 (n y units) * 65536 (left over slope error) = 286,326,784
    # error_per_y_unit = 1456.33333333 = 1456 (truncated the .3333333 since this is int division)
    # error_remainder = 286,326,784 - (1456 * 196608 = 286,261,248) = 65536 * sign_dx
    # error_bump = 1456 * sign_dx = 1456
    # x_per_unit_step = 13107 + 1456 = 14563
    assert_equal(w.error_step, 65536)
    assert_equal(w.step_x, 14563)
    # error_step starts with:
    # error_remainder = 4370 (n y units) * 65536 (left over slope error) = 286,392,320
    # x_per_unit_dy = 3 * 4370 = 13110
    # error_per_y_unit = 1456.66666667 = 1456 (truncated the .66666667 since this is int division)
    # error_remainder = 286,326,784 - (1456 * 196608 = 286,261,248) = 131072 * sign_dx
    # error_bump = 1456 * sign_dx = 1456
    # x_per_unit_step = 13110 + 1456 = 14566
    assert_equal(w.error_remainder_step, 131072)
    assert_equal(w.step_x_remainder, 14566)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
