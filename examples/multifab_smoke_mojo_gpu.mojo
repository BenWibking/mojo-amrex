"""Smoke example for Mojo device kernels over staged AMReX tile data.

This path uses Mojo GPU buffers and launches, but AMReX itself remains on the
host side in this repo.
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
    StagedTileF32,
    TileF32View,
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


def fill_tile[
    owner_origin: Origin[mut=True]
](tile: TileF32View[owner_origin]) raises:
    tile.fill(Float32(1.0))


fn update_tile_gpu(
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
        dst[i, j, k] = src[i, j, k] + add_value


def update_tile_with_gpu[
    src_origin: Origin[mut=True],
    dst_origin: Origin[mut=True],
](
    ref ctx: DeviceContext,
    src_tile: TileF32View[src_origin],
    dst_tile: TileF32View[dst_origin],
    add_value: Float32,
) raises:
    var src_stage = StagedTileF32(ctx, src_tile)
    var dst_stage = StagedTileF32(ctx, dst_tile)
    ctx.enqueue_function[update_tile_gpu, update_tile_gpu](
        src_stage.device_view(),
        dst_stage.device_view(),
        dst_stage.tile_box,
        add_value,
        grid_dim=ceildiv(dst_stage.cell_count(), KERNEL_BLOCK_SIZE),
        block_dim=KERNEL_BLOCK_SIZE,
    )
    dst_stage.store_to_host(ctx, dst_tile)
    ctx.synchronize()


def main() raises:
    if not has_accelerator():
        raise Error(
            "examples/multifab_smoke_mojo_gpu.mojo requires a Mojo-supported accelerator for the staged user-kernel path."
        )

    var runtime = AmrexRuntime()

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
    var source = MultiFabF32(
        runtime, boxarray, distmap, 1, intvect3d(1, 1, 1)
    )

    var params = ParmParse(runtime, "multifab_smoke_mojo_gpu")
    params.add_int("tile_fill_value", 42)

    var add_value = Float32(params.query_int("tile_fill_value") - 1)
    var plotfile_path = String("build/multifab_smoke_mojo_gpu_plotfile")

    source.for_each_tile[fill_tile]()
    multifab.set_val(Float32(0.0))

    var ctx = DeviceContext()
    ctx.synchronize()

    var mfi = multifab.mfiter()
    while mfi.is_valid():
        _ = mfi.tilebox()
        _ = mfi.validbox()
        _ = mfi.fabbox()
        _ = mfi.growntilebox()
        update_tile_with_gpu(
            ctx,
            source.tile(mfi),
            multifab.tile(mfi),
            add_value,
        )

        mfi.next()

    var ntile = multifab.tile_count()
    multifab.write_single_level_plotfile(plotfile_path, geometry)

    print("boxes=", boxarray.size())
    print("nprocs=", runtime.nprocs())
    print("tiles=", ntile)
    print("sum=", multifab.sum(0))
