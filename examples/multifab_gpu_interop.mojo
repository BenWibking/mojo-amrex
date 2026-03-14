"""Smoke example for direct Mojo GPU kernels over AMReX-managed device data.

This path requires an AMReX library built with CUDA or HIP support so Mojo can
share its current stream with AMReX and borrow device-accessible `Array4`
metadata without staging through Mojo-owned buffers.
"""

from amrex.space3d import (
    AmrexRuntime,
    Array4F32View,
    Box3D,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFabF32,
    ParmParse,
    box3d,
    intvect3d,
)
from std.gpu import global_idx
from std.gpu.host import DeviceContext
from std.math import ceildiv
from std.sys import has_accelerator


comptime DOMAIN_EXTENT = 64
comptime TILE_EXTENT = 32
comptime KERNEL_BLOCK_SIZE = 256


def cell_count(box: Box3D) -> Int:
    return (
        (Int(box.big_end.x) - Int(box.small_end.x) + 1)
        * (Int(box.big_end.y) - Int(box.small_end.y) + 1)
        * (Int(box.big_end.z) - Int(box.small_end.z) + 1)
    )


def update_tile_gpu(
    src: Array4F32View[MutAnyOrigin],
    dst: Array4F32View[MutAnyOrigin],
    tile_box: Box3D,
    add_value: Float32,
):
    var tid = global_idx.x
    var tile_lo_x = Int(tile_box.small_end.x)
    var tile_lo_y = Int(tile_box.small_end.y)
    var tile_lo_z = Int(tile_box.small_end.z)
    var tile_hi_x = Int(tile_box.big_end.x)
    var tile_hi_y = Int(tile_box.big_end.y)
    var tile_hi_z = Int(tile_box.big_end.z)
    var nx = tile_hi_x - tile_lo_x + 1
    var ny = tile_hi_y - tile_lo_y + 1
    var nz = tile_hi_z - tile_lo_z + 1
    var active_cells = nx * ny * nz
    if tid < UInt(active_cells):
        var linear_index = Int(tid)
        var cells_per_plane = nx * ny
        var k = tile_lo_z + linear_index // cells_per_plane
        var plane_index = linear_index % cells_per_plane
        var j = tile_lo_y + plane_index // nx
        var i = tile_lo_x + plane_index % nx
        dst.data[dst.offset(i, j, k)] = (
            src.data[src.offset(i, j, k)] + add_value
        )


def launch_update_tile(
    ref ctx: DeviceContext,
    src: Array4F32View[MutAnyOrigin],
    dst: Array4F32View[MutAnyOrigin],
    tile_box: Box3D,
    add_value: Float32,
) raises:
    ctx.enqueue_function[update_tile_gpu, update_tile_gpu](
        src,
        dst,
        tile_box,
        add_value,
        grid_dim=ceildiv(cell_count(tile_box), KERNEL_BLOCK_SIZE),
        block_dim=KERNEL_BLOCK_SIZE,
    )


def require_direct_gpu_interop(
    ref runtime: AmrexRuntime, ref multifab: MultiFabF32
) raises:
    if runtime.gpu_backend() == "none":
        raise Error(
            "examples/multifab_gpu_interop.mojo requires AMReX built with CUDA"
            " or HIP support."
        )

    if not has_accelerator():
        raise Error(
            "examples/multifab_gpu_interop.mojo requires a Mojo-supported"
            " accelerator."
        )

    var info = multifab.memory_info()
    if not info.device_accessible:
        raise Error(
            "The example requires a device-accessible MultiFab allocation. Use"
            " the default arena in a CUDA/HIP AMReX build."
        )


def main() raises:
    if not has_accelerator():
        raise Error(
            "examples/multifab_gpu_interop.mojo requires a Mojo-supported"
            " accelerator."
        )
    var ctx = DeviceContext()
    var runtime = AmrexRuntime(Int(ctx.id()))

    var domain = box3d(
        small_end=intvect3d(0, 0, 0),
        big_end=intvect3d(
            DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1
        ),
    )

    var boxarray = BoxArray(runtime, domain)
    boxarray.max_size(TILE_EXTENT)

    var distmap = DistributionMapping(runtime, boxarray)
    var geometry = Geometry(runtime, domain)
    _ = geometry.domain()
    _ = geometry.prob_domain()
    _ = geometry.cell_size()
    _ = geometry.periodicity()
    var multifab = MultiFabF32(
        runtime, boxarray, distmap, 1, intvect3d(1, 1, 1)
    )
    var source = MultiFabF32(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))

    require_direct_gpu_interop(runtime, source)
    require_direct_gpu_interop(runtime, multifab)

    var params = ParmParse(runtime, "multifab_gpu_interop")
    params.add_int("tile_fill_value", 42)

    var add_value = Float32(params.query_int("tile_fill_value") - 1)
    var plotfile_path = String("build/multifab_gpu_interop_plotfile")

    # Keep this scope live while AMReX calls and Mojo kernels share ctx.stream().
    var stream_scope = runtime.external_gpu_stream_scope(
        ctx, sync_on_exit=False
    )

    source.set_val(Float32(1.0))
    multifab.set_val(Float32(0.0))

    var mfi = multifab.mfiter()
    while mfi.is_valid():
        var tile_box = mfi.tilebox()
        _ = mfi.validbox()
        _ = mfi.fabbox()
        _ = mfi.growntilebox()

        var src_array = source.unsafe_device_array(mfi)
        var dst_array = multifab.unsafe_device_array(mfi)
        launch_update_tile(
            ctx,
            src_array.device_view(),
            dst_array.device_view(),
            tile_box,
            add_value,
        )

        mfi.next()

    ctx.synchronize()

    var ntile = multifab.tile_count()
    var info = multifab.memory_info()
    multifab.write_single_level_plotfile(plotfile_path, geometry)

    print("backend=", runtime.gpu_backend())
    print("device_accessible=", info.device_accessible)
    print("host_accessible=", info.host_accessible)
    print("boxes=", boxarray.size())
    print("nprocs=", runtime.nprocs())
    print("tiles=", ntile)
    print("sum=", multifab.sum(0))
