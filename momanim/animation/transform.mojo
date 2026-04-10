from momanim.animation.animation import Animatable


from momanim.mobject.polygram import MObject, MorphingVMObject
from momanim.mobject.bezier_curve import QuadBezierCurve
from momanim.mobject.bezier_curve import interpolate


struct Transform[
    SourceObject: MObject,
    TargetObject: MObject,
    source_origin: Origin,
    target_origin: Origin,
](Animatable):
    comptime S = Self.SourceObject
    comptime T = Self.TargetObject
    comptime K = MorphingVMObject[Self.S.CoordDType, Self.T.CoordDType]

    var starting_obj: Pointer[mut=False, Self.SourceObject, Self.source_origin]
    var target_obj: Pointer[mut=False, Self.TargetObject, Self.target_origin]
    var morphing_obj: Self.K
    var run_time: Float32
    "The time the animation will run for in seconds."
    var _current_frame: UInt
    var _total_frames: UInt

    def __init__(
        out self,
        ref[Self.source_origin] source_obj: Self.SourceObject,
        ref[Self.target_origin] target_obj: Self.TargetObject,
        run_time: Float32 = 2.0,
    ) raises:
        self.starting_obj = Pointer[mut=False](to=source_obj)
        self.target_obj = Pointer[mut=False](to=target_obj)
        self.morphing_obj = MorphingVMObject[
            Self.S.CoordDType, Self.T.CoordDType
        ](
            start_curves=self.starting_obj[].copy_curves(),
            end_curves=self.target_obj[].copy_curves(),
            start_style=self.starting_obj[].get_style(),
            end_style=self.target_obj[].get_style(),
        )
        self.run_time = run_time
        self._current_frame = 0
        self._total_frames = 0

    def begin(mut self, fps: UInt) raises -> None:
        self._current_frame = 0
        self._total_frames = UInt(self.run_time * Float32(fps))

    def step(mut self) raises -> Self.K:
        var max_delta: Float32 = 0.0
        if self._current_frame > 0:
            max_delta = Float32(self._current_frame) / Float32(
                self._total_frames
            )

        var copy_obj = self.morphing_obj.copy()
        copy_obj = copy_obj.morph(
            self.morphing_obj,
            a=0,
            b=max_delta,
        )
        var current_style = self.morphing_obj.start_style.copy()
        current_style.color_fill = interpolate[DType.float32, 4](
            self.morphing_obj.start_style.color_fill.cast[DType.float32](),
            self.morphing_obj.end_style.color_fill.cast[DType.float32](),
            max_delta,
        ).cast[DType.uint8]()
        current_style.color_edges = interpolate[DType.float32, 4](
            self.morphing_obj.start_style.color_edges.cast[DType.float32](),
            self.morphing_obj.end_style.color_edges.cast[DType.float32](),
            max_delta,
        ).cast[DType.uint8]()
        self.morphing_obj.current_style = current_style^

        self._current_frame += 1
        return copy_obj^

    def end(mut self) -> None:
        self._current_frame = self._total_frames

    def is_finished(self) -> Bool:
        return self._current_frame > self._total_frames
