from momanim.io_backends.mav.image_read import image_read
from momanim.io_backends.mav.image_write import image_write
from momanim.io_backends.mav.video_read import video_read
from momanim.io_backends.mav.video_write import video_write
from std.testing import TestSuite
from std.pathlib import Path
from std.os import getenv
from std.os.path import join
from std.testing import assert_equal, assert_true
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat
from momanim.constants import ColorSpace
import numojo as nm


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


def test_image_read_127x127() raises:
    """127x127: width*3=381. Verifies image read + numojo indexing with line_size.
    """
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root, "test_data/generate_test_videos_testsrc_127x127.png"
    )
    var image = image_read(root_path)
    assert_equal(image.w, 127)
    assert_equal(image.h, 127)
    assert_equal(image.ch, 3)
    assert_equal(image.line_size, 128 * 3)
    var arr = image.numojo()
    assert_equal(arr.item(0, 0, 0), 0)
    assert_equal(arr.item(0, 0, 1), 0)
    assert_equal(arr.item(0, 0, 2), 0)
    assert_equal(arr.item(126, 126, 0), 255)
    assert_equal(arr.item(126, 126, 1), 255)
    assert_equal(arr.item(126, 126, 2), 255)


def test_image_write() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root, "test_data/generate_test_videos_testsrc_128x128.png"
    )
    var image = image_read(root_path)
    var save_path = join(
        test_data_root, "test_data/test_mav/test_image_write.png"
    )
    image_write(image, save_path)


def test_video_read() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root,
        "test_data/generate_test_videos_testsrc_320x180_30fps_2s.mp4",
    )
    var videos = video_read(root_path)
    assert_equal(videos[0].w, 320)
    assert_equal(videos[0].h, 180)
    assert_equal(videos[0].color_space, ColorSpace.RGB_24)
    assert_equal(videos[0].ch, 3)
    assert_equal(len(videos[0]._frames), 60)

    for i in range(len(videos[0]._frames)):
        var frame = videos[0].numojo(i)
        assert_equal(frame.shape[0], 180)
        assert_equal(frame.shape[1], 320)
        assert_equal(frame.shape[2], 3)
        # Anchor RGBs match AArch64/x86 with SWS_BITEXACT|ACCURATE_RND (mav/utils.mojo).
        if i == 59:
            assert_equal(frame[0, 0].tolist(), [253, 0, 0])
        elif i == 0:
            assert_equal(frame[169, 309].tolist(), [0, 254, 254])

        if i == 0:
            var segment_inc = 320 / 6
            var segment_start = 0
            print(
                "Red:    ",
                frame[180 - 1, segment_start + 2]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Green:  ",
                frame[180 - 1, segment_start + 2]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Yellow: ",
                frame[180 - 1, segment_start + 2]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Blue:   ",
                frame[180 - 1, segment_start + 2]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Pink:   ",
                frame[180 - 1, segment_start + 2]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Cyan:   ",
                frame[180 - 1, segment_start + 2]._array_to_string(0, 0),
            )


def test_video_write() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root,
        "test_data/generate_test_videos_testsrc_320x180_30fps_2s.mp4",
    )
    var videos = video_read(root_path)
    var save_path = join(
        test_data_root, "test_data/test_mav/test_video_save.mp4"
    )
    video_write(videos, Path(save_path))
    var save_path_2 = join(
        test_data_root, "test_data/test_mav/test_video_save.webm"
    )
    video_write(videos, Path(save_path_2))


def main() raises:
    # NOTE: valgrind should produce max 242 blocks.
    TestSuite.discover_tests[__functions_in_module()]().run()
