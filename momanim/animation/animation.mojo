from momanim.mobject.bezier_curve import QuadBezierCurve


trait Animatable(ImplicitlyDestructible, Movable):
    def is_finished(self) -> Bool:
        ...

    def begin(mut self, fps: UInt) raises -> None:
        ...

    def step(mut self) raises -> List[QuadBezierCurve[DType.float32]]:
        ...

    def end(mut self) -> None:
        ...
