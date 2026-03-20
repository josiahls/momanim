from momanim.io_backends.mav.image_read import image_read
from momanim.io_backends.mav.image_save import image_save
from momanim.io_backends.mav.video_read import video_read
from std.testing import TestSuite
from std.os import getenv
from std.os.path import join
from std.testing import assert_equal, assert_true
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

        if i == 0:
            var segment_inc = 320 / 6
            var segment_start = 0
            print(
                "Red:    ",
                frame[180 - 5, segment_start + 10]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Green:  ",
                frame[180 - 5, segment_start + 10]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Yellow: ",
                frame[180 - 5, segment_start + 10]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Blue:   ",
                frame[180 - 5, segment_start + 10]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Pink:   ",
                frame[180 - 5, segment_start + 10]._array_to_string(0, 0),
                end=" ",
            )
            segment_start += segment_inc
            print(
                "Cyan:   ",
                frame[180 - 5, segment_start + 10]._array_to_string(0, 0),
            )


def main() raises:
    # TestSuite.discover_tests[__functions_in_module()]().run()
    # test_image_save()
    test_video_read()
