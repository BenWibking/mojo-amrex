from amrex.space3d import (
    AmrexRuntime,
    Box3D,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParmParse,
    TileF64View,
    box3d,
    intvect3d,
)
from layout import Layout, LayoutTensor
from std.gpu import global_idx
from std.gpu.host import DeviceContext
from std.math import ceildiv
from std.sys import has_apple_gpu_accelerator


comptime DOMAIN_EXTENT = 64
comptime TILE_EXTENT = 32
comptime MAX_TILE_CELLS = TILE_EXTENT * TILE_EXTENT * TILE_EXTENT
comptime KERNEL_BLOCK_SIZE = 256
comptime STAGING_LAYOUT = Layout.row_major(MAX_TILE_CELLS)


def fill_tile[
    owner_origin: Origin[mut=True]
](tile: TileF64View[owner_origin]) raises:
    tile.fill(1.0)


def tile_cell_count(tile_box: Box3D) raises -> Int:
    return (
        (Int(tile_box.big_end.x) - Int(tile_box.small_end.x) + 1)
        * (Int(tile_box.big_end.y) - Int(tile_box.small_end.y) + 1)
        * (Int(tile_box.big_end.z) - Int(tile_box.small_end.z) + 1)
    )


# Apple GPU kernels run through Metal, which does not expose Float64 arithmetic.
fn update_tile_gpu(
    src: LayoutTensor[DType.float32, STAGING_LAYOUT, MutAnyOrigin],
    dst: LayoutTensor[DType.float32, STAGING_LAYOUT, MutAnyOrigin],
    active_cells: Int,
    add_value: Float32,
):
    var tid = global_idx.x
    if tid < UInt(active_cells):
        var linear_index = Int(tid)
        dst[linear_index] = src[linear_index] + add_value


def main() raises:
    if not has_apple_gpu_accelerator():
        raise Error(
            "examples/multifab_smoke_apple_gpu.mojo requires an Apple Silicon GPU."
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
    var multifab = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
    var source = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))

    var params = ParmParse(runtime, "multifab_smoke_apple_gpu")
    params.add_int("tile_fill_value", 42)

    var add_value = Float32(params.query_int("tile_fill_value") - 1)
    var plotfile_path = String("build/multifab_smoke_apple_gpu_plotfile")

    source.for_each_tile[fill_tile]()
    multifab.set_val(0.0)

    var ctx = DeviceContext()
    var src_host_buffer = ctx.enqueue_create_host_buffer[DType.float32](
        MAX_TILE_CELLS
    )
    var dst_host_buffer = ctx.enqueue_create_host_buffer[DType.float32](
        MAX_TILE_CELLS
    )
    var src_device_buffer = ctx.enqueue_create_buffer[DType.float32](
        MAX_TILE_CELLS
    )
    var dst_device_buffer = ctx.enqueue_create_buffer[DType.float32](
        MAX_TILE_CELLS
    )
    ctx.synchronize()

    var src_tensor = LayoutTensor[DType.float32, STAGING_LAYOUT](
        src_device_buffer
    )
    var dst_tensor = LayoutTensor[DType.float32, STAGING_LAYOUT](
        dst_device_buffer
    )

    var mfi = multifab.mfiter()
    while mfi.is_valid():
        var tile_box = mfi.tilebox()
        _ = mfi.validbox()
        _ = mfi.fabbox()
        _ = mfi.growntilebox()
        var dst_array = multifab.array(mfi)
        var src_array = source.array(mfi)
        var active_cells = tile_cell_count(tile_box)

        var linear_index = 0
        for k in range(Int(tile_box.small_end.z), Int(tile_box.big_end.z) + 1):
            for j in range(
                Int(tile_box.small_end.y), Int(tile_box.big_end.y) + 1
            ):
                for i in range(
                    Int(tile_box.small_end.x), Int(tile_box.big_end.x) + 1
                ):
                    src_host_buffer[linear_index] = Float32(src_array[i, j, k])
                    linear_index += 1

        ctx.enqueue_copy(src_buf=src_host_buffer, dst_buf=src_device_buffer)
        ctx.enqueue_function[update_tile_gpu, update_tile_gpu](
            src_tensor,
            dst_tensor,
            active_cells,
            add_value,
            grid_dim=ceildiv(active_cells, KERNEL_BLOCK_SIZE),
            block_dim=KERNEL_BLOCK_SIZE,
        )
        ctx.enqueue_copy(src_buf=dst_device_buffer, dst_buf=dst_host_buffer)
        ctx.synchronize()

        linear_index = 0
        for k in range(Int(tile_box.small_end.z), Int(tile_box.big_end.z) + 1):
            for j in range(
                Int(tile_box.small_end.y), Int(tile_box.big_end.y) + 1
            ):
                for i in range(
                    Int(tile_box.small_end.x), Int(tile_box.big_end.x) + 1
                ):
                    dst_array[i, j, k] = Float64(dst_host_buffer[linear_index])
                    linear_index += 1

        mfi.next()

    var ntile = multifab.tile_count()
    multifab.write_single_level_plotfile(plotfile_path, geometry)

    print("boxes=", boxarray.size())
    print("nprocs=", runtime.nprocs())
    print("tiles=", ntile)
    print("sum=", multifab.sum(0))
