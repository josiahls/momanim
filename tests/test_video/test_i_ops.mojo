from std.testing import TestSuite, assert_equal
from std.os import getenv
from std.os.path import join
from std.pathlib import Path
from momanim.video.i_ops import video_read
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat


def test_video_read() raises:
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root,
        "test_data/generate_test_videos_testsrc_320x180_30fps_2s.mp4",
    )
    var videos = video_read(root_path)
    print("done reading video")
    assert_equal(videos[0].width, 320)
    assert_equal(videos[0].height, 180)
    assert_equal(videos[0].format, AVPixelFormat.AV_PIX_FMT_YUV420P._value)
    assert_equal(videos[0].n_color_spaces, 2)

    print("n_frames: ", videos[0].n_frames)
    for frame in range(videos[0].n_frames):
        var frame_data = videos[0].data[frame]
        var n_pixels = videos[0].width * videos[0].height
        for pixel in range(n_pixels):
            print(frame_data[pixel])
        assert_equal(frame_data[0], 0)
        assert_equal(frame_data[49151], 255)

    # # NOTE: Simple test, we know that the first element is is black
    # # and the last element is white.
    # assert_equal(video.data[0], 0)
    # assert_equal(video.data[49151], 255)


def main() raises:
    # TestSuite.discover_tests[__functions_in_module()]().run()
    test_video_read()
    # test_video_save()
