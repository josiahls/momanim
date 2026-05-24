"""



Reference implementation is taken from Cairo's perf tooling:

- https://gitlab.freedesktop.org/cairo/cairo.git commit 8e3ac5

"""

from std.io.file import FileHandle

from momanim.pix_forge.context import PixForgeContext

comptime PerfTime = Int64


struct Target(Copyable):
    var name: StaticString
    var basename: StaticString
    var file_extension: StaticString


struct Perf:
    var summary: FileHandle
    var summary_continuous: Bool

    # CLI options
    var iterations: Int
    var exact_iterations: Bool
    var raw: Bool
    var list_only: Bool
    var observe: Bool
    var names: List[StaticString]
    var exlude_names: List[StaticString]
    var exact_names: Bool

    var ms_per_iteration: Float64
    var fast_and_sloopy: Bool

    var tile_size: Int

    # Interal
    var times: List[PerfTime]
    var targets: List[Target]
    var target: UnsafePointer[Target, MutExternalOrigin]
    # TODO: I think this is the current active target
    var test_number: Int
    var size: Int
    var context: PixForgeContext


def perf_run(
    mut perf: Perf,
    name: StaticString,
    perf_func: def(width: Int, height: Int, loops: Int) raises -> PerfTime,
):
    pass
