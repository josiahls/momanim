from std.pathlib import Path
from std.os import getenv
from std.logger import Logger
from std.sys.defines import get_defined_string
from momanim.pix_forge.output import surface_to_png
from momanim.pix_forge.surface import *


comptime logger = Logger()


# TODO: Can we make surface parametric? More specifically, SHOULD we?
@always_inline
def test_surface_to_png[
    module_name: StaticString,
    test_name: StaticString,
](surface: ColorSurface) raises:
    """
    Save the surface to a PNG file in the `test_data` directory.

    Only enabled when the `MOMANIM_TEST_OUTPUT` compile time flag is set to `1`.

    The file name will be `pixi_project_root/test_data/{module_name}/{test_name}.png`.

    Parameters:
        module_name: The name of the module.
        test_name: The name of the test.

    Args:
        surface: The surface to save.
    """
    comptime if get_defined_string["MOMANIM_TEST_OUTPUT"]() == "1":
        var root = Path(getenv("PIXI_PROJECT_ROOT")) / "test_data" / module_name
        root /= test_name + ".png"
        logger.debug(t"Saving test output to `{root}`.")
        surface_to_png(surface, root)
