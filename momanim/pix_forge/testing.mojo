from std.pathlib import Path
from std.os import getenv
from std.logger import Logger
from std.sys.defines import get_defined_string
from momanim.pix_forge.output import surface_to_png
from momanim.pix_forge.surface import *


comptime logger = Logger()


@always_inline
def test_surface_to_png(
    surface: Some[Surfaceable],
    module_name: StaticString,
    test_name: StaticString,
):
    comptime if get_defined_string["MOMANIM_TEST_OUTPUT"]() == "1":
        var root = Path(getenv("PIXI_PROJECT_ROOT")) / "test_data" / module_name
        root /= test_name + ".png"
        logger.debug(t"Saving test output to `{root}`.")
        surface_to_png(surface, root)
