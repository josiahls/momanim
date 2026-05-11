from std.testing import (
    TestSuite, 
    assert_equal, 
    assert_not_equal, 
    assert_true, 
    assert_false
)
from std.math import floor

from momanim.rasterization.geometry_2d import FixedPoint2d, FixedPointEdge2d, Edge2dWalker, Point2d



def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
