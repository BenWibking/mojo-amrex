"""Minimal reproducer for incorrect Mojo GPU writes through zero-copy host pointers.

On affected Apple Silicon systems, a kernel that writes directly into a
host-backed `List[c_float]` through a zero-copy pointer leaves the host buffer
unchanged. The same kernel works when launched against a staged `DeviceBuffer`
and copied back to the host.
"""

from std.builtin.device_passable import DevicePassable
from std.collections import List
from std.ffi import c_float
from std.gpu import global_idx
from std.gpu.host import DeviceContext
from std.math import ceildiv
from std.sys import has_accelerator


comptime ELEMENT_COUNT = 4096
comptime BLOCK_SIZE = 256
comptime FILL_VALUE = Float32(42.0)


def init_device_passable_value[
    T: TrivialRegisterPassable,
    mut_origin: Origin[mut=True],
](value: T, target: UnsafePointer[NoneType, mut_origin]):
    target.bitcast[T]().init_pointee_copy(value)


@fieldwise_init
struct BufferViewF32(TrivialRegisterPassable, DevicePassable):
    comptime device_type = Self

    var data: UnsafePointer[c_float, MutAnyOrigin]
    var size: Int64

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](
        self,
        target: UnsafePointer[NoneType, mut_origin],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("BufferViewF32")

    def __getitem__(self, index: Int) -> Float32:
        return self.data[index]

    def __setitem__(self, index: Int, value: Float32):
        self.data[index] = value


def host_view(mut storage: List[c_float]) -> BufferViewF32:
    return BufferViewF32(
        data=storage.unsafe_ptr(),
        size=Int64(len(storage)),
    )


def sum_buffer(view: BufferViewF32) -> Float64:
    var total = Float64(0.0)
    for i in range(Int(view.size)):
        total += Float64(view[i])
    return total


def fill_buffer_gpu(dst: BufferViewF32, value: Float32):
    var tid = global_idx.x
    if tid < Int(dst.size):
        dst[Int(tid)] = value


def fill_with_gpu_zero_copy(
    ref ctx: DeviceContext, dst: BufferViewF32, value: Float32
) raises:
    ctx.enqueue_function[fill_buffer_gpu, fill_buffer_gpu](
        dst,
        value,
        grid_dim=ceildiv(Int(dst.size), BLOCK_SIZE),
        block_dim=BLOCK_SIZE,
    )
    ctx.synchronize()


def fill_with_gpu_staged(
    ref ctx: DeviceContext, dst: BufferViewF32, value: Float32
) raises:
    var buffer = ctx.enqueue_create_buffer[DType.float32](Int(dst.size))
    var device_view = BufferViewF32(
        data=buffer.unsafe_ptr(),
        size=dst.size,
    )
    ctx.enqueue_function[fill_buffer_gpu, fill_buffer_gpu](
        device_view,
        value,
        grid_dim=ceildiv(Int(device_view.size), BLOCK_SIZE),
        block_dim=BLOCK_SIZE,
    )
    ctx.enqueue_copy[DType.float32](dst.data, buffer)
    ctx.synchronize()


def main() raises:
    if not has_accelerator():
        raise Error(
            "issues/apple_silicon_zero_copy_host_buffer_gpu_repro.mojo requires a Mojo-supported accelerator."
        )

    var zero_copy_storage = List[c_float](length=ELEMENT_COUNT, fill=0.0)
    var staged_storage = List[c_float](length=ELEMENT_COUNT, fill=0.0)
    var zero_copy_view = host_view(zero_copy_storage)
    var staged_view = host_view(staged_storage)

    var ctx = DeviceContext()
    ctx.synchronize()

    fill_with_gpu_zero_copy(ctx, zero_copy_view, FILL_VALUE)
    fill_with_gpu_staged(ctx, staged_view, FILL_VALUE)

    var expected_sum = Float64(ELEMENT_COUNT) * Float64(FILL_VALUE)
    var zero_copy_sum = sum_buffer(zero_copy_view)
    var staged_sum = sum_buffer(staged_view)

    print("elements=", ELEMENT_COUNT)
    print("expected_sum=", expected_sum)
    print("zero_copy_sum=", zero_copy_sum)
    print("staged_sum=", staged_sum)
    print("zero_copy_matches_expected=", zero_copy_sum == expected_sum)
    print("staged_matches_expected=", staged_sum == expected_sum)
