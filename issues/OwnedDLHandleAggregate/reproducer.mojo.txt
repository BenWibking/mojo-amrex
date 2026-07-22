# ABOUTME: Reproduces incorrect C ABI lowering for an aggregate passed by value through OwnedDLHandle.call.
# ABOUTME: Build aggregate.c first, then run this file from its containing directory.

from std.ffi import OwnedDLHandle, c_int


@fieldwise_init
struct Aggregate3x3(TrivialRegisterPassable, Writable):
    var x0: c_int
    var x1: c_int
    var x2: c_int
    var y0: c_int
    var y1: c_int
    var y2: c_int
    var z0: c_int
    var z1: c_int
    var z2: c_int


def main() raises:
    var lib = OwnedDLHandle("./libaggregate.dylib")
    var values = [
        Aggregate3x3(
            x0=1,
            x1=2,
            x2=3,
            y0=4,
            y1=5,
            y2=6,
            z0=7,
            z1=8,
            z2=9,
        )
    ]

    var pointer_result = Int(lib.call["sum_aggregate_pointer", c_int](values.unsafe_ptr()))
    print("pointer control:", pointer_result, flush=True)

    var by_value_result = Int(lib.call["sum_aggregate", c_int](values[0]))
    print("by value:      ", by_value_result, flush=True)
