from std.reflection import struct_field_names, struct_field_types


trait Enumable(Equatable, ImplicitlyCopyable, Writable):
    comptime dtype = Int

    @implicit
    def __init__(out self, value: Self.dtype):
        ...

    def __init__(out self, enum: Self):
        ...
