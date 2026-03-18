from std.testing import TestSuite, assert_equal
from std.os import getenv
from std.os.path import join
from momanim.image.io import image_read, image_save
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat


def test_image_read() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root, "test_data/generate_test_videos_testsrc_128x128.png"
    )
    var image = image_read(root_path)
    assert_equal(image.width, 128)
    assert_equal(image.height, 128)
    assert_equal(image.format, AVPixelFormat.AV_PIX_FMT_RGB24._value)
    assert_equal(image.n_color_spaces, 2)

    # NOTE: Simple test, we know that the first element is is black
    # and the last element is white.
    assert_equal(image.data[0], 0)
    assert_equal(image.data[49151], 255)


def test_image_save() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root, "test_data/generate_test_videos_testsrc_128x128.png"
    )
    var save_path = join(test_data_root, "test_data/test_image_save.png")
    var image = image_read(root_path)
    image_save(image, save_path)

    var image2 = image_read(save_path)
    assert_equal(image2.width, 128)
    assert_equal(image2.height, 128)
    assert_equal(image2.format, AVPixelFormat.AV_PIX_FMT_RGB24._value)
    assert_equal(image2.n_color_spaces, 2)

    # NOTE: Simple test, we know that the first element is is black
    # and the last element is white.
    assert_equal(image2.data[0], 0)
    assert_equal(image2.data[49151], 255)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
    # test_image_save()
