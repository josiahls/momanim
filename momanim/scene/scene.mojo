from momanim.animation.animation import Animatable
from momanim.camera.camera import Camera
from momanim.typing import SIMD


trait Scenable(ImplicitlyDestructible, Movable):
    # fn construct(self) -> None:
    #     """
    #     Construct the scene.
    #     """
    #     ...

    # fn play[obj: Animatable](self, *args: obj) -> None:
    #     """
    #     Play the scene.
    #     """
    #     ...

    # fn render(self) raises -> None:
    #     """
    #     Render the scene.
    #     """
    # ...
    def cameras(self) -> List[Camera]:
        ...

    def background_color(self) -> SIMD[DType.uint8, 4]:
        ...
