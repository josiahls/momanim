from std.subprocess import run
from std.os import abort
from std.utils._ansi import Color, Text
from std.testing.suite import TestSuiteReport, TestReport, TestResult
from std.reflection import call_location
from std.pathlib import Path
from std.time import perf_counter_ns
from std.algorithm.functional import sync_parallelize


comptime TEST_DIR = Path("tests")


def test_file(file: Path) raises -> TestReport:
    var start = perf_counter_ns()
    var result = run("pixi run test_no_config " + String(file) + " 2>&1")
    var end = perf_counter_ns()
    var duration_ns = end - start
    if (
        "Unhandled exception caught during execution" in result
        or "FAIL " in result
        or "bin/mojo: error: " in result
    ):
        return TestReport.failed(
            name=file.name(), duration_ns=duration_ns, error=Error(result)
        )

    return TestReport.passed(name=file.name(), duration_ns=duration_ns)


def walk_tests(path: Path, mut test_files: List[Path]) raises:
    for f in path.listdir():
        file = path / f
        if file.is_file() and file.suffix() == ".mojo":
            print("Found test file: ", Text[Color.CYAN](file))
            test_files.append(file)
        elif file.is_dir():
            walk_tests(file, test_files)


def parallel_exec(
    test_files: List[Path], mut test_results: List[TestReport]
) raises:
    var progress = 0
    var n_files = len(test_files)

    @parameter
    fn exec_test(thread_id: Int):
        var file = test_files[thread_id]
        try:
            var test_result = test_file(file)
            test_results.append(test_result^)
        except e:
            var test_result = TestReport.failed(
                name=file.name(), duration_ns=0, error=Error(e)
            )
            test_results.append(test_result^)
        progress += 1
        print(
            # https://web.archive.org/web/20121225024852/http://www.climagic.org/mirrors/VT100_Escape_Codes.html
            "\33[2K[",
            "=" * progress,
            " " * (n_files - progress),
            "] %",
            (Float32(progress) / Float32(n_files)) * 100,
            end="\r",
            sep="",
            flush=True,
        )

    sync_parallelize[exec_test](n_files)


def main() raises:
    var test_results = List[TestReport]()
    var test_files = List[Path]()
    walk_tests(TEST_DIR, test_files)
    parallel_exec(test_files, test_results)
    var report = TestSuiteReport(
        reports=test_results^, location=call_location[inline_count=0]()
    )
    print(report)
    if report.failures > 0:
        abort("Tests failed")
