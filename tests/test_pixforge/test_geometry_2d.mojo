from std.testing import (
    TestSuite, 
    assert_equal, 
    assert_not_equal, 
    assert_true, 
    assert_false
)
from std.math import floor

from momanim.rasterization.geometry_2d import FixedPoint2d, FixedPointEdge2d, FixedPointTrapezoid2d, Point2d, Vector2d
from momanim.rasterization.fixed_dtype import FixedInt


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()