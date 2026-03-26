from std.testing import TestSuite, assert_equal
from momanim.constants import ColorSpace, RIGHT
from std.math import tau
from momanim.scene.scene import Scene
from momanim.mobject.geometry.polygram import Square
from momanim.animation.animation import Animatable
from momanim.animation.creation import Create


struct SquareToCircle(Scene):
    def __init__(out self):
        pass


    def play[obj: Animatable](self, *args: obj) -> None:
        print('im doing it.')


    def construct(self):
        # circle = Circle()
        square = Square()
        square.flip(RIGHT)
        square.rotate(-3 * tau / 8)
        # circle.set_fill(PINK, opacity=0.5)

        self.play(Create(square))
        # self.play(Transform(square, circle))
        # self.play(FadeOut(square))


def test_SquareToCircle() raises:
    var scene = SquareToCircle()
    scene.construct()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
