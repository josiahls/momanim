from std.testing import TestSuite, assert_equal
from std.os import getenv
from std.os.path import join
from std.pathlib import Path
from momanim.video.io import video_read, video_save
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat


def test_video_read() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root,
        "test_data/generate_test_videos_testsrc_320x180_30fps_2s.mp4",
    )
    var videos = video_read(root_path)
    assert_equal(videos[0].width, 320)
    assert_equal(videos[0].height, 180)
    assert_equal(videos[0].format, AVPixelFormat.AV_PIX_FMT_YUV420P._value)
    assert_equal(videos[0].n_color_spaces, 2)

    # # NOTE: Simple test, we know that the first element is is black
    # # and the last element is white.
    # assert_equal(video.data[0], 0)
    # assert_equal(video.data[49151], 255)


def test_video_save() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root,
        "test_data/generate_test_videos_testsrc_320x180_30fps_2s.mp4",
    )
    var videos = video_read(root_path)
    var save_path = join(test_data_root, "test_data/test_video_save_2.mp4")
    video_save(videos, Path(save_path))

    # var video2 = video_read(save_path)
    # assert_equal(video2.width, 320)
    # assert_equal(video2.height, 180)
    # assert_equal(video2.format, AVPixelFormat.AV_PIX_FMT_YUV420P._value)
    # assert_equal(video2.n_color_spaces, 2)


#     # NOTE: Simple test, we know that the first element is is black
#     # and the last element is white.
#     assert_equal(video2.data[0], 0)
#     assert_equal(video2.data[49151], 255)


def main() raises:
    # TestSuite.discover_tests[__functions_in_module()]().run()
    # test_video_read()
    test_video_save()
