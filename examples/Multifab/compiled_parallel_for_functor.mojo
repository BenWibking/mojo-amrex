"""Minimal example for hoisting `parallel_for` compilation with a functor body."""

from amrex.space3d import (
    AmrexRuntime,
    Array4F64View,
    Box3D,
    BoxArray,
    DistributionMapping,
    MultiFab,
    box3d,
    intvect3d,
)
from amrex.ffi import init_device_passable_value
from std.builtin.device_passable import DevicePassable, DeviceTypeEncoder
from std.gpu import global_idx
from std.gpu.host import DeviceContext
from std.math import ceildiv


comptime KERNEL_BLOCK_SIZE = 256


@fieldwise_init
struct ScaleAndShiftCell(DevicePassable, TrivialRegisterPassable):
    comptime device_type = Self

    var dst: Array4F64View[MutAnyOrigin]
    var src: Array4F64View[MutAnyOrigin]
    var scale: Float64
    var shift: Float64

    def _to_device_type(
        self,
        mut encoder: Some[DeviceTypeEncoder],
        target: UnsafePointer[mut=True, NoneType, _],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("ScaleAndShiftCell")

    def __call__(self, i: Int, j: Int, k: Int) register_passable:
        self.dst[i, j, k] = self.src[i, j, k] * self.scale + self.shift


def cell_count(tile_box: Box3D) -> Int:
    return (
        (Int(tile_box.big_end.x) - Int(tile_box.small_end.x) + 1)
        * (Int(tile_box.big_end.y) - Int(tile_box.small_end.y) + 1)
        * (Int(tile_box.big_end.z) - Int(tile_box.small_end.z) + 1)
    )


def scale_and_shift_kernel(body: ScaleAndShiftCell, tile_box: Box3D):
    var tid = global_idx.x
    var lo_x = Int(tile_box.small_end.x)
    var lo_y = Int(tile_box.small_end.y)
    var lo_z = Int(tile_box.small_end.z)
    var nx = Int(tile_box.big_end.x) - lo_x + 1
    var ny = Int(tile_box.big_end.y) - lo_y + 1
    var active_cells = cell_count(tile_box)
    if tid < active_cells:
        var linear_index = Int(tid)
        var cells_per_plane = nx * ny
        var k = lo_z + linear_index // cells_per_plane
        var plane_index = linear_index % cells_per_plane
        var j = lo_y + plane_index // nx
        var i = lo_x + plane_index % nx
        body(i, j, k)


def expect_equal(
    actual: Float64, expected: Float64, message: StringLiteral
) raises:
    if actual != expected:
        raise Error(message)


def main() raises:
    var ctx = DeviceContext()
    var runtime = AmrexRuntime(Int(ctx.id()))
    try:
        var domain = box3d(
            small_end=intvect3d(0, 0, 0),
            big_end=intvect3d(31, 31, 31),
        )

        var boxarray = BoxArray(runtime, domain)
        boxarray.max_size(16)
        var distmap = DistributionMapping(runtime, boxarray)

        var source = MultiFab(runtime, boxarray, distmap, 1)
        var destination = MultiFab(runtime, boxarray, distmap, 1)
        source.set_val(2.0)
        destination.set_val(0.0)

        var update_kernel = ctx.compile_function[scale_and_shift_kernel]()

        var mfi = destination.mfiter()
        while mfi.is_valid():
            var tile_box = mfi.tilebox()
            var stream = mfi.stream(ctx)
            var body = ScaleAndShiftCell(
                dst=destination.array(mfi).device_view(),
                src=source.array(mfi).device_view(),
                scale=3.0,
                shift=1.0,
            )
            stream.enqueue_function(
                update_kernel,
                body,
                tile_box,
                grid_dim=ceildiv(cell_count(tile_box), KERNEL_BLOCK_SIZE),
                block_dim=KERNEL_BLOCK_SIZE,
            )
            mfi.next()

        expect_equal(
            destination.sum(0),
            7.0 * 32.0 * 32.0 * 32.0,
            "compiled functor update mismatch",
        )
        print("compiled functor parallel_for: ok")
        runtime^.close()
    except e:
        runtime^.close()
        raise e^
