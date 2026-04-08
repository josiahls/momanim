from std.testing import TestSuite, assert_equal
from std.memory import AddressSpace, UnsafePointer


struct MyType[
    mut: Bool,
    //,
    origin: Origin[mut=mut],
    address_space: AddressSpace,
    dtype: DType = DType.float64,
]:
    # Intentionally minimal: just enough shape to start iterating.
    var _ptr: UnsafePointer[Scalar[Self.dtype],origin=Self.origin, address_space=Self.address_space]

    def __init__(out self, ptr: UnsafePointer[Scalar[Self.dtype], Self.origin, address_space=Self.address_space]):
        self._ptr = ptr

    def insert(ref[Self.origin] self, val: Scalar[Self.dtype]) where Self.mut:
        # Don’t “solve” design yet; just make the test harness callable.
        self._ptr.store(val=val, offset=0)


def test_my_type_insert_stores_value() raises:
    var slot = alloc[Float64](1)
    var wrapper = MyType(ptr=slot)
    wrapper.insert(2.5)
    assert_equal(slot.load()[0], 2.5)

    var slot2 = alloc[Float64](1).as_immutable()
    # var wrapper2 = MyType(ptr=slot2)
    # wrapper2.insert(2.5) # Should fail to compile
    # assert_equal(slot2.load()[0], 2.5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
