from std.testing import (
    TestSuite, 
    assert_equal, 
    assert_not_equal, 
    assert_true, 
    assert_false
)
from std.math import floor

from momanim.rasterization.geometry_2d import FixedPoint2d, FixedPointEdge2d, Point2d, Vector2d, HalfPlane2d
from momanim.rasterization.fixed_dtype import FixedInt
from momanim.rasterization.fixed_point_trap_2d import FixedPointTrap2d, Line2d, Span2d



def test_Line2d__init__() raises:
    # Quad 1
    var v1: Vector2d = {{0,0}, {10,10}}
    var l1 = Line2d(v1, 1.0)
    assert_equal(l1.v_l.round[2](), Vector2d({0.35, -0.35}, {10.35, 9.65}))
    assert_equal(l1.v_r.round[2](), Vector2d({-0.35, 0.35}, {9.65, 10.35}))
    # Quad 1 2
    var v12: Vector2d = {{0,0}, {0,10}}
    var l12 = Line2d(v12, 1.0)
    assert_equal(l12.v_l.round[2](), Vector2d({0.5, 0.0}, {0.5, 10.0}))
    assert_equal(l12.v_r.round[2](), Vector2d({-0.5, 0.0}, {-0.5, 10.0}))
    # Quad 2
    var v2: Vector2d = {{0,0}, {-10,10}}
    var l2 = Line2d(v2, 1.0)
    assert_equal(l2.v_l.round[2](), Vector2d({0.35, 0.35}, {-9.65, 10.35}))
    assert_equal(l2.v_r.round[2](), Vector2d({-0.35, -0.35}, {-10.35, 9.65}))
    # Quad 2 3
    var v23: Vector2d = {{0,0}, {-10, 0}}
    var l23 = Line2d(v23, 1.0)
    assert_equal(l23.v_l.round[2](), Vector2d({0.0, 0.5}, {-10.0, 0.5}))
    assert_equal(l23.v_r.round[2](), Vector2d({0.0, -0.5}, {-10.0, -0.5}))
    # Quad 3
    var v3: Vector2d = {{0,0}, {-10,-10}}
    var l3 = Line2d(v3, 1.0)
    assert_equal(l3.v_l.round[2](), Vector2d({-0.35, 0.35}, {-10.35, -9.65}))
    assert_equal(l3.v_r.round[2](), Vector2d({0.35, -0.35}, {-9.65, -10.35}))
    # Quad 3 4
    var v34: Vector2d = {{0,0}, {0, -10}}
    var l34 = Line2d(v34, 1.0)
    assert_equal(l34.v_l.round[2](), Vector2d({-0.5, -0.0}, {-0.5, -10.0}))
    assert_equal(l34.v_r.round[2](), Vector2d({0.5, 0.0}, {0.5, -10.0}))
    # Quad 4
    var v4: Vector2d = {{0,0}, {10,-10}}
    var l4 = Line2d(v4, 1.0)
    assert_equal(l4.v_l.round[2](), Vector2d({-0.35, -0.35}, {9.65, -10.35}))
    assert_equal(l4.v_r.round[2](), Vector2d({0.35, 0.35}, {10.35, -9.65}))
    # Quad 4 1
    var v41: Vector2d = {{0,0}, {10, 0}}
    var l41 = Line2d(v41, 1.0)
    assert_equal(l41.v_l.round[2](), Vector2d({0.0, -0.5}, {10.0, -0.5}))
    assert_equal(l41.v_r.round[2](), Vector2d({0.0, 0.5}, {10.0, 0.5}))


def test_Line2d_into_span_2ds() raises:
    # Quad 1
    var v1: Vector2d = {{0,0}, {10,10}}
    var l1 = Line2d(v1, 1.0)
    var spans1 = l1^.into_spans()
    assert_equal(len(spans1), 4)
    assert_equal(spans1[0].round[2](), Span2d({0.35, -0.35}, {0.35, -0.35}))
    assert_equal(spans1[1].round[2](), Span2d({-0.35, 0.35}, {1.06, 0.35}))
    assert_equal(spans1[2].round[2](), Span2d({8.94, 9.65}, {10.35, 9.65}))
    assert_equal(spans1[3].round[2](), Span2d({9.65, 10.35}, {9.65, 10.35}))
    # Quad 1 2
    var v12: Vector2d = {{0,0}, {0,10}}
    var l12 = Line2d(v12, 1.0)
    var spans12 = l12^.into_spans()
    assert_equal(len(spans12), 2)
    assert_equal(spans12[0].round[2](), Span2d({-0.5, 0.0}, {0.5, 0.0}))
    assert_equal(spans12[1].round[2](), Span2d({-0.5, 10.0}, {0.5, 10.0}))
    # Quad 2
    var v2: Vector2d = {{0,0}, {-10,10}}
    var l2 = Line2d(v2, 1.0)
    var spans2 = l2^.into_spans()
    assert_equal(len(spans2), 4)
    assert_equal(spans2[0].round[2](), Span2d({-0.35, -0.35}, {-0.35, -0.35}))
    assert_equal(spans2[1].round[2](), Span2d({-1.06, 0.35}, {0.35, 0.35}))
    assert_equal(spans2[2].round[2](), Span2d({-10.35, 9.65}, {-8.94, 9.65}))
    assert_equal(spans2[3].round[2](), Span2d({-9.65, 10.35}, {-9.65, 10.35}))
    # Quad 2 3
    var v23: Vector2d = {{0,0}, {-10, 0}}
    var l23 = Line2d(v23, 1.0)
    var spans23 = l23^.into_spans()
    assert_equal(len(spans23), 2)
    assert_equal(spans23[0].round[2](), Span2d({-10.0, -0.5}, {0.0, -0.5}))
    assert_equal(spans23[1].round[2](), Span2d({-10.0, 0.5}, {0.0, 0.5}))
    # Quad 3
    var v3: Vector2d = {{0,0}, {-10,-10}}
    var l3 = Line2d(v3, 1.0)
    var spans3 = l3^.into_spans()
    assert_equal(len(spans3), 4)
    assert_equal(spans3[0].round[2](), Span2d({-9.65, -10.35}, {-9.65, -10.35}))
    assert_equal(spans3[1].round[2](), Span2d({-10.35, -9.65}, {-8.94, -9.65}))
    assert_equal(spans3[2].round[2](), Span2d({-1.06, -0.35}, {0.35, -0.35}))
    assert_equal(spans3[3].round[2](), Span2d({-0.35, 0.35}, {-0.35, 0.35}))
    # Quad 3 4
    var v34: Vector2d = {{0,0}, {0, -10}}
    var l34 = Line2d(v34, 1.0)
    var spans34 = l34^.into_spans()
    assert_equal(len(spans34), 2)
    assert_equal(spans34[0].round[2](), Span2d({-0.5, -10.0}, {0.5, -10.0}))
    assert_equal(spans34[1].round[2](), Span2d({-0.5, 0.0}, {0.5, 0.0}))
    # Quad 4
    var v4: Vector2d = {{0,0}, {10,-10}}
    var l4 = Line2d(v4, 1.0)
    var spans4 = l4^.into_spans()
    assert_equal(len(spans4), 4)
    assert_equal(spans4[0].round[2](), Span2d({9.65, -10.35}, {9.65, -10.35}))
    assert_equal(spans4[1].round[2](), Span2d({8.94, -9.65}, {10.35, -9.65}))
    assert_equal(spans4[2].round[2](), Span2d({-0.35, -0.35}, {1.06, -0.35}))
    assert_equal(spans4[3].round[2](), Span2d({0.35, 0.35}, {0.35, 0.35}))
    # Quad 4 1
    var v41: Vector2d = {{0,0}, {10, 0}}
    var l41 = Line2d(v41, 1.0)
    var spans41 = l41^.into_spans()
    assert_equal(len(spans41), 2)
    assert_equal(spans41[0].round[2](), Span2d({0.0, -0.5}, {10.0, -0.5}))
    assert_equal(spans41[1].round[2](), Span2d({0.0, 0.5}, {10.0, 0.5}))




def test_FixedPointTrap2d__init__a_b_c_d() raises:
    # Quad 1
    var trap1 = FixedPointTrap2d({0.35,-0.35}, {-0.35,0.35}, {1.06,0.35}, {0.35,-0.35})
    assert_equal(trap1.l, FixedPointEdge2d({0.35, -0.35}, {-0.35, 0.35}))
    assert_equal(trap1.r, FixedPointEdge2d({1.06, 0.35}, {0.35, -0.35}))
    assert_equal(trap1.top, FixedInt(from_float=-0.35))
    assert_equal(trap1.bot, FixedInt(from_float=0.35))
    # Quad 1 2
    var trap12 = FixedPointTrap2d({-0.5, 0.0}, {-0.5, 10.0}, {0.5, 10.0}, {0.5, 0.0})
    assert_equal(trap12.l, FixedPointEdge2d({-0.5, 0.0}, {-0.5, 10.0}))
    assert_equal(trap12.r, FixedPointEdge2d({0.5, 10.0}, {0.5, 0.0}))
    assert_equal(trap12.top, FixedInt(from_float=0.0))
    assert_equal(trap12.bot, FixedInt(from_float=10.0))
    # Quad 2
    var trap2 = FixedPointTrap2d({-0.35, -0.35}, {-1.06, 0.35}, {0.35, 0.35}, {-0.35, -0.35})
    assert_equal(trap2.l, FixedPointEdge2d({-0.35, -0.35}, {-1.06, 0.35}))
    assert_equal(trap2.r, FixedPointEdge2d({0.35, 0.35}, {-0.35, -0.35}))
    assert_equal(trap2.top, FixedInt(from_float=-0.35))
    assert_equal(trap2.bot, FixedInt(from_float=0.35))
    # Quad 2 3
    var trap23 = FixedPointTrap2d({-10.0, -0.5}, {-10.0, 0.5}, {0.0, 0.5}, {0.0, -0.5})
    assert_equal(trap23.l, FixedPointEdge2d({-10.0, -0.5}, {-10.0, 0.5}))
    assert_equal(trap23.r, FixedPointEdge2d({0.0, 0.5}, {0.0, -0.5}))
    assert_equal(trap23.top, FixedInt(from_float=-0.5))
    assert_equal(trap23.bot, FixedInt(from_float=0.5))
    # Quad 3
    var trap3 = FixedPointTrap2d({-9.65, -10.35}, {-10.35, -9.65}, {-8.94, -9.65}, {-9.65, -10.35})
    assert_equal(trap3.l, FixedPointEdge2d({-9.65, -10.35}, {-10.35, -9.65}))
    assert_equal(trap3.r, FixedPointEdge2d({-8.94, -9.65}, {-9.65, -10.35}))
    assert_equal(trap3.top, FixedInt(from_float=-10.35))
    assert_equal(trap3.bot, FixedInt(from_float=-9.65))
    # Quad 3 4
    var trap34 = FixedPointTrap2d({-0.5, -10.0}, {-0.5, 0.0}, {0.5, 0.0}, {0.5, -10.0})
    assert_equal(trap34.l, FixedPointEdge2d({-0.5, -10.0}, {-0.5, 0.0}))
    assert_equal(trap34.r, FixedPointEdge2d({0.5, 0.0}, {0.5, -10.0}))
    assert_equal(trap34.top, FixedInt(from_float=-10.0))
    assert_equal(trap34.bot, FixedInt(from_float=0.0))
    # Quad 4
    var trap4 = FixedPointTrap2d({9.65, -10.35}, {8.94, -9.65}, {10.35, -9.65}, {9.65, -10.35})
    assert_equal(trap4.l, FixedPointEdge2d({9.65, -10.35}, {8.94, -9.65}))
    assert_equal(trap4.r, FixedPointEdge2d({10.35, -9.65}, {9.65, -10.35}))
    assert_equal(trap4.top, FixedInt(from_float=-10.35))
    assert_equal(trap4.bot, FixedInt(from_float=-9.65))
    # Quad 4 1
    var trap41 = FixedPointTrap2d({0.0, -0.5}, {0.0, 0.5}, {10.0, 0.5}, {10.0, -0.5})
    assert_equal(trap41.l, FixedPointEdge2d({0.0, -0.5}, {0.0, 0.5}))
    assert_equal(trap41.r, FixedPointEdge2d({10.0, 0.5}, {10.0, -0.5}))
    assert_equal(trap41.top, FixedInt(from_float=-0.5))
    assert_equal(trap41.bot, FixedInt(from_float=0.5))



def test_FixedPointTrap2d__from_line() raises:
    # Quad 1
    var v1: Vector2d = {{0,0}, {10,10}}
    var traps1 = FixedPointTrap2d.from_line(v1, 1.0)
    assert_equal(len(traps1), 3)
    assert_equal(traps1[0].l.vector_2d[2](), Vector2d({0.35, -0.35}, {-0.35, 0.35}))
    assert_equal(traps1[0].r.vector_2d[2](), Vector2d({1.06, 0.35}, {0.35, -0.35}))
    assert_equal(traps1[0].is_degenerate(), True)
    assert_equal(traps1[1].l.vector_2d[2](), Vector2d({-0.35, 0.35}, {8.94, 9.65}))
    assert_equal(traps1[1].r.vector_2d[2](), Vector2d({10.35, 9.65}, {1.06, 0.35}))
    assert_equal(traps1[1].is_degenerate(), False)
    assert_equal(traps1[2].l.vector_2d[2](), Vector2d({8.94, 9.65}, {9.65, 10.35}))
    assert_equal(traps1[2].r.vector_2d[2](), Vector2d({9.65, 10.35}, {10.35, 9.65}))
    assert_equal(traps1[2].is_degenerate(), True)
    # Quad 1 2
    var v12: Vector2d = {{0,0}, {0,10}}
    var traps12 = FixedPointTrap2d.from_line(v12, 1.0)
    assert_equal(len(traps12), 1)
    assert_equal(traps12[0].is_degenerate(), False)
    assert_equal(traps12[0].l.vector_2d[2](), Vector2d({-0.5, 0.0}, {-0.5, 10.0}))
    assert_equal(traps12[0].r.vector_2d[2](), Vector2d({0.5, 10.0}, {0.5, 0.0}))
    # Quad 2
    var v2: Vector2d = {{0,0}, {-10,10}}
    var traps2 = FixedPointTrap2d.from_line(v2, 1.0)
    assert_equal(len(traps2), 3)
    assert_equal(traps2[0].l.vector_2d[2](), Vector2d({-0.35, -0.35}, {-1.06, 0.35}))
    assert_equal(traps2[0].r.vector_2d[2](), Vector2d({0.35, 0.35}, {-0.35, -0.35}))
    assert_equal(traps2[0].is_degenerate(), True)
    assert_equal(traps2[1].l.vector_2d[2](), Vector2d({-1.06, 0.35}, {-10.35, 9.65}))
    assert_equal(traps2[1].r.vector_2d[2](), Vector2d({-8.94, 9.65}, {0.35, 0.35}))
    assert_equal(traps2[1].is_degenerate(), False)
    assert_equal(traps2[2].l.vector_2d[2](), Vector2d({-10.35, 9.65}, {-9.65, 10.35}))
    assert_equal(traps2[2].r.vector_2d[2](), Vector2d({-9.65, 10.35}, {-8.94, 9.65}))
    assert_equal(traps2[2].is_degenerate(), True)
    # Quad 2 3
    var v23: Vector2d = {{0,0}, {-10, 0}}
    var traps23 = FixedPointTrap2d.from_line(v23, 1.0)
    assert_equal(len(traps23), 1)
    assert_equal(traps23[0].is_degenerate(), False)
    assert_equal(traps23[0].l.vector_2d[2](), Vector2d({-10.0, -0.5}, {-10.0, 0.5}))
    assert_equal(traps23[0].r.vector_2d[2](), Vector2d({0.0, 0.5}, {0.0, -0.5}))
    # Quad 3
    var v3: Vector2d = {{0,0}, {-10,-10}}
    var traps3 = FixedPointTrap2d.from_line(v3, 1.0)
    assert_equal(len(traps3), 3)
    assert_equal(traps3[0].l.vector_2d[2](), Vector2d({-9.65, -10.35}, {-10.35, -9.65}))
    assert_equal(traps3[0].r.vector_2d[2](), Vector2d({-8.94, -9.65}, {-9.65, -10.35}))
    assert_equal(traps3[0].is_degenerate(), True)
    assert_equal(traps3[1].l.vector_2d[2](), Vector2d({-10.35, -9.65}, {-1.06, -0.35}))
    assert_equal(traps3[1].r.vector_2d[2](), Vector2d({0.35, -0.35}, {-8.94, -9.65}))
    assert_equal(traps3[1].is_degenerate(), False)
    assert_equal(traps3[2].l.vector_2d[2](), Vector2d({-1.06, -0.35}, {-0.35, 0.35}))
    assert_equal(traps3[2].r.vector_2d[2](), Vector2d({-0.35, 0.35}, {0.35, -0.35}))
    assert_equal(traps3[2].is_degenerate(), True)
    # Quad 3 4
    var v34: Vector2d = {{0,0}, {0, -10}}
    var traps34 = FixedPointTrap2d.from_line(v34, 1.0)
    assert_equal(traps34[0].is_degenerate(), False)
    assert_equal(len(traps34), 1)
    assert_equal(traps34[0].l.vector_2d[2](), Vector2d({-0.5, -10.0}, {-0.5, 0.0}))
    assert_equal(traps34[0].r.vector_2d[2](), Vector2d({0.5, 0.0}, {0.5, -10.0}))
    # Quad 4
    var v4: Vector2d = {{0,0}, {10,-10}}
    var traps4 = FixedPointTrap2d.from_line(v4, 1.0)
    assert_equal(len(traps4), 3)
    assert_equal(traps4[0].l.vector_2d[2](), Vector2d({9.65, -10.35}, {8.94, -9.65}))
    assert_equal(traps4[0].r.vector_2d[2](), Vector2d({10.35, -9.65}, {9.65, -10.35}))
    assert_equal(traps4[0].is_degenerate(), True)
    assert_equal(traps4[1].l.vector_2d[2](), Vector2d({8.94, -9.65}, {-0.35, -0.35}))
    assert_equal(traps4[1].r.vector_2d[2](), Vector2d({1.06, -0.35}, {10.35, -9.65}))
    assert_equal(traps4[1].is_degenerate(), False)
    assert_equal(traps4[2].l.vector_2d[2](), Vector2d({-0.35, -0.35}, {0.35, 0.35}))
    assert_equal(traps4[2].r.vector_2d[2](), Vector2d({0.35, 0.35}, {1.06, -0.35}))
    assert_equal(traps4[2].is_degenerate(), True)
    # Quad 4 1
    var v41: Vector2d = {{0,0}, {10, 0}}
    var traps41 = FixedPointTrap2d.from_line(v41, 1.0)
    assert_equal(len(traps41), 1)
    assert_equal(traps41[0].is_degenerate(), False)
    assert_equal(traps41[0].l.vector_2d[2](), Vector2d({0.0, -0.5}, {0.0, 0.5}))
    assert_equal(traps41[0].r.vector_2d[2](), Vector2d({10.0, 0.5}, {10.0, -0.5}))



def test_FixedPointTrap2d__from_line_edge_cases() raises:
    # Narrow Line
    var v1: Vector2d = {{0,0}, {10, 10}}
    var traps1 = FixedPointTrap2d.from_line(v1, 0.0)
    assert_equal(len(traps1), 1)
    assert_equal(traps1[0].is_degenerate(), True)
    assert_equal(traps1[0].l.vector_2d[2](), Vector2d({0.0, 0.0}, {10.0, 10.0}))
    assert_equal(traps1[0].r.vector_2d[2](), Vector2d({10.0, 10.0}, {0.0, 0.0}))
    # Point
    var v2: Vector2d = {{0,0}, {0, 0}}
    var traps2 = FixedPointTrap2d.from_line(v2, 0.0)
    assert_equal(len(traps2), 1)
    assert_equal(traps2[0].is_degenerate(), True)
    assert_equal(traps2[0].l.vector_2d[2](), Vector2d({0.0, 0.0}, {0.0, 0.0}))
    assert_equal(traps2[0].r.vector_2d[2](), Vector2d({0.0, 0.0}, {0.0, 0.0}))
    # Odd line thickness
    var v3: Vector2d = {{0,0}, {10, 10}}
    var traps3 = FixedPointTrap2d.from_line(v3, 0.3)
    assert_equal(len(traps3), 3)
    assert_equal(traps3[0].is_degenerate(), True)
    assert_equal(traps3[0].l.vector_2d[2](), Vector2d({0.11, -0.11}, {-0.11, 0.11}))
    assert_equal(traps3[0].r.vector_2d[2](), Vector2d({0.32, 0.11}, {0.11, -0.11}))
    assert_equal(traps3[1].is_degenerate(), False)
    assert_equal(traps3[1].l.vector_2d[2](), Vector2d({-0.11, 0.11}, {9.68, 9.89}))
    assert_equal(traps3[1].r.vector_2d[2](), Vector2d({10.11, 9.89}, {0.32, 0.11}))
    assert_equal(traps3[2].is_degenerate(), True)
    assert_equal(traps3[2].l.vector_2d[2](), Vector2d({9.68, 9.89}, {9.89, 10.11}))
    assert_equal(traps3[2].r.vector_2d[2](), Vector2d({9.89, 10.11}, {10.11, 9.89}))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()