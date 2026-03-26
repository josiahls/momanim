from momanim.animation.animation import Animatable


trait Scenable(ImplicitlyDestructible, Movable):
    fn construct(self) -> None:
        """
        Construct the scene.
        """
        ...

    fn play[obj: Animatable](self, *args: obj) -> None:
        """
        Play the scene.
        """
        ...
