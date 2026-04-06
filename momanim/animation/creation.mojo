from momanim.animation.animation import Animatable


from momanim.mobject.polygram import Square
from momanim.mobject.bezier_curve import QuadBezierCurve


struct Create[origin: Origin](Animatable):
    var starting_obj: Pointer[mut=False, Square[DType.float32], Self.origin]
    var run_time: Float32
    "The time the animation will run for in seconds."
    var _current_frame: UInt
    var _total_frames: UInt

    def __init__(out self, ref[Self.origin] obj: Square[DType.float32]) raises:
        self.starting_obj = Pointer[mut=False](to=obj)
        self.run_time = 4
        self._current_frame = 0
        self._total_frames = 0

    def begin(mut self, fps: UInt) raises -> None:
        self._current_frame = 0
        self._total_frames = UInt(self.run_time * Float32(fps))

    def step(mut self) raises -> List[QuadBezierCurve[DType.float32]]:
        var max_delta: Float32 = 0.0
        if self._current_frame > 0:
            max_delta = Float32(self._current_frame) / Float32(
                self._total_frames
            )

        # var total_pixels = Int(L * max_delta) + 1
        var draw_actions = List[QuadBezierCurve[DType.float32]](capacity=3)

        var copy_obj = self.starting_obj[].copy()
        copy_obj = copy_obj.pointwise_become_partial(
            self.starting_obj[],
            a=0,
            b=max_delta,
        )
        for curve in copy_obj.curves:
            draw_actions.append(curve)

        self._current_frame += 1
        return draw_actions^

    def end(mut self) -> None:
        self._current_frame = self._total_frames

    def is_finished(self) -> Bool:
        return self._current_frame > self._total_frames
