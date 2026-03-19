from momanim.io_backends.mav.image_read import image_read
from momanim.io_backends.mav.image_save import image_save
from std.testing import TestSuite
from std.os import getenv
from std.os.path import join
from std.testing import assert_equal
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat
from momanim.constants import ColorSpace


def test_image_read() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root, "test_data/generate_test_videos_testsrc_128x128.png"
    )
    var image = image_read(root_path)
    assert_equal(image.w, 128)
    assert_equal(image.h, 128)
    assert_equal(image.color_space, ColorSpace.RGB_24)
    assert_equal(image.ch, 3)

    # NOTE: Simple test, we know that the first element is is black
    # and the last element is white.
    assert_equal(image._data.ptr[0], 0)
    assert_equal(image._data.ptr[49151], 255)


def test_image_save() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root, "test_data/generate_test_videos_testsrc_128x128.png"
    )
    var image = image_read(root_path)
    var save_path = join(
        test_data_root, "test_data/test_mav/test_image_save.png"
    )
    image_save(image, save_path)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
    # test_image_save()
