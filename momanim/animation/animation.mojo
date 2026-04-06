from momanim.mobject.polygram import MObject


trait Animatable(ImplicitlyDestructible, Movable):
    comptime K: MObject

    def is_finished(self) -> Bool:
        ...

    def begin(mut self, fps: UInt) raises -> None:
        ...

    def step(mut self) raises -> Self.K:
        ...

    def end(mut self) -> None:
        ...
