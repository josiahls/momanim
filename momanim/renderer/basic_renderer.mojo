from momanim.data_structs.video import Video
from momanim.scene.scene import Scenable
from momanim.camera.camera import Camera
from std.pathlib import Path


struct BasicRenderer[Scene: Scenable, origin: Origin](Movable):
    var video: Video[DType.uint8]
    var scene: Pointer[Self.Scene, Self.origin]
    var path: Path

    def __init__(
        out self,
        ref[Self.origin] scene: Self.Scene,
        path: Optional[Path] = None,
    ) raises:
        self.scene = Pointer(to=scene)
        self.video = Video[DType.uint8]()
        self.path = path[] if path else Path()

    fn render(self) raises:
        pass
