from momanim.data_structs.video import Video
from std.testing import TestSuite, assert_equal, assert_raises
from momanim.constants import ColorSpace


def test_video_init_validate() raises:
    var elements: List[UInt8] = [1, 2, 3, 4]
    with assert_raises(contains="must be a multiple"):
        var _ = Video(elements^)


def test_video_init_from_list() raises:
    var elements: List[UInt8] = [1, 2, 3, 4, 5, 6]
    var video = Video(elements^)
    assert_equal(video.w, 6)
    assert_equal(video.h, 1)
    assert_equal(video.ch, 1)
    assert_equal(video.color_space, ColorSpace.RGB_24)


def test_video_init_from_ptr() raises:
    var elements: List[UInt8] = [1, 2, 3, 4, 5, 6]
    var ptr = elements.unsafe_ptr().unsafe_origin_cast[MutExternalOrigin]()
    var video = Video(ptr, 6)
    assert_equal(video.w, 6)
    assert_equal(video.h, 1)
    assert_equal(video.ch, 1)
    assert_equal(video.color_space, ColorSpace.RGB_24)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
