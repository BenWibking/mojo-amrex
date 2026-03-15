"""Direct Mojo GPU kernels over AMReX-managed device data."""

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
    var lo_x = Int(tile_box.small_end.x)
    var lo_y = Int(tile_box.small_end.y)
    var lo_z = Int(tile_box.small_end.z)
    var nx = Int(tile_box.big_end.x) - lo_x + 1
    var ny = Int(tile_box.big_end.y) - lo_y + 1
    var active_cells = cell_count(tile_box)
    if tid < UInt(active_cells):
        var linear_index = Int(tid)
        var cells_per_plane = nx * ny
        var k = lo_z + linear_index // cells_per_plane
        var plane_index = linear_index % cells_per_plane
        var j = lo_y + plane_index // nx
        var i = lo_x + plane_index % nx
        dst[i, j, k] = src[i, j, k] + add_value


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
    if not info.is_device and not info.is_managed:
        print(
            "warning: direct GPU interop is borrowing a MultiFab that is"
            " device-accessible but neither device nor managed according to"
            " AMReX memory_info()."
        )


def main() raises:
    var ctx = DeviceContext()
    var runtime = AmrexRuntime(Int(ctx.id()))

    comptime DOMAIN_EXTENT = 64
    var domain = box3d(
        small_end=intvect3d(0, 0, 0),
        big_end=intvect3d(
            DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1
        ),
    )

    var boxarray = BoxArray(runtime, domain)
    comptime TILE_EXTENT = 32
    boxarray.max_size(TILE_EXTENT)

    var distmap = DistributionMapping(runtime, boxarray)
    var geometry = Geometry(runtime, domain)
    var destination = MultiFabF32(
        runtime, boxarray, distmap, 1, intvect3d(1, 1, 1)
    )
    var source = MultiFabF32(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))

    require_direct_gpu_interop(runtime, source)
    require_direct_gpu_interop(runtime, destination)

    var params = ParmParse(runtime, "multifab_gpu_interop")
    params.add_int("tile_fill_value", 42)

    var add_value = Float32(params.query_int("tile_fill_value") - 1)
    var plotfile_path = String("build/multifab_gpu_interop_plotfile")

    # Keep this scope live while AMReX calls and Mojo kernels share ctx.stream().
    var stream_scope = runtime.external_gpu_stream_scope(
        ctx, sync_on_exit=False
    )

    # runs on device
    source.set_val(Float32(1.0))
    destination.set_val(Float32(0.0))

    # loop over tiles on the device and launch a kernel for each
    var mfi = destination.mfiter()
    while mfi.is_valid():
        var tile_box = mfi.tilebox()
        var src_array = source.unsafe_device_array(mfi)
        var dst_array = destination.unsafe_device_array(mfi)
        launch_update_tile(ctx, src_array, dst_array, tile_box, add_value)
        mfi.next()

    ctx.synchronize()

    # write plotfile
    destination.write_single_level_plotfile(plotfile_path, geometry)

    # print diagnostics
    print("backend=", runtime.gpu_backend())
    print("boxes=", boxarray.size())
    print("nprocs=", runtime.nprocs())
    print("tiles=", destination.tile_count())
    print("sum=", destination.sum(0))
