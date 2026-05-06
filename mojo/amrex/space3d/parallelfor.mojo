"""`ParallelFor` helpers for 3D tile boxes."""

from amrex.ffi import Box3D
from amrex.space3d.mfiter import GpuMFIter
from std.builtin.device_passable import DevicePassable
from std.gpu import global_idx
from std.gpu.host import DeviceContext
from std.math import ceildiv


comptime KERNEL_BLOCK_SIZE = 256


def ParallelFor[body_type: def(Int, Int, Int) raises -> None](body: body_type, tile_box: Box3D) raises:
    for k in range(Int(tile_box.small_end.z), Int(tile_box.big_end.z) + 1):
        for j in range(Int(tile_box.small_end.y), Int(tile_box.big_end.y) + 1):
            for i in range(Int(tile_box.small_end.x), Int(tile_box.big_end.x) + 1):
                body(i, j, k)


def cell_count(box: Box3D) -> Int:
    return (
        (Int(box.big_end.x) - Int(box.small_end.x) + 1)
        * (Int(box.big_end.y) - Int(box.small_end.y) + 1)
        * (Int(box.big_end.z) - Int(box.small_end.z) + 1)
    )


def _parallel_for_kernel[
    body_type: def(Int, Int, Int) -> None
](body: body_type, tile_box: Box3D) where conforms_to(body_type, DevicePassable):
    var tid = global_idx.x
    var lo_x = Int(tile_box.small_end.x)
    var lo_y = Int(tile_box.small_end.y)
    var lo_z = Int(tile_box.small_end.z)
    var nx = Int(tile_box.big_end.x) - lo_x + 1
    var ny = Int(tile_box.big_end.y) - lo_y + 1
    var active_cells = nx * ny * (Int(tile_box.big_end.z) - lo_z + 1)
    if tid < active_cells:
        var linear_index = Int(tid)
        var cells_per_plane = nx * ny
        var k = lo_z + linear_index // cells_per_plane
        var plane_index = linear_index % cells_per_plane
        var j = lo_y + plane_index // nx
        var i = lo_x + plane_index % nx
        body(i, j, k)


def ParallelFor[
    body_type: def(Int, Int, Int) -> None
](
    body: body_type,
    ref ctx: DeviceContext,
    ref mfi: GpuMFIter,
    tile_box: Box3D,
) raises where conforms_to(
    body_type, DevicePassable
):
    _ = mfi.stream(ctx)
    ctx.enqueue_function[_parallel_for_kernel[body_type]](
        body,
        tile_box,
        grid_dim=ceildiv(cell_count(tile_box), KERNEL_BLOCK_SIZE),
        block_dim=KERNEL_BLOCK_SIZE,
    )
