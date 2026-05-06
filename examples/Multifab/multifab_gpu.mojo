"""Direct Mojo GPU kernels over AMReX-managed device data."""

from amrex.space3d import (
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFabF32,
    ParallelFor,
    ParmParse,
    box3d,
    intvect3d,
)
from std.gpu.host import DeviceContext
from std.sys import has_accelerator


def require_direct_gpu_interop(ref runtime: AmrexRuntime, ref multifab: MultiFabF32) raises:
    if runtime.gpu_backend() == "none":
        raise Error("examples/multifab_gpu_interop.mojo requires AMReX built with CUDA or HIP support.")

    if not has_accelerator():
        raise Error("examples/multifab_gpu_interop.mojo requires a Mojo-supported accelerator.")

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
    try:
        comptime DOMAIN_EXTENT = 64
        var domain = box3d(
            small_end=intvect3d(0, 0, 0),
            big_end=intvect3d(DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1),
        )

        var boxarray = BoxArray(runtime, domain)
        comptime TILE_EXTENT = 32
        boxarray.max_size(TILE_EXTENT)

        var distmap = DistributionMapping(runtime, boxarray)
        var geometry = Geometry(runtime, domain)
        var destination = MultiFabF32(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var source = MultiFabF32(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))

        require_direct_gpu_interop(runtime, source)
        require_direct_gpu_interop(runtime, destination)

        var params = ParmParse(runtime, "multifab_gpu_interop")
        params.add_int("tile_fill_value", 42)

        var add_value = Float32(params.query_int("tile_fill_value") - 1)
        var plotfile_path = String("build/multifab_gpu_interop_plotfile")

        # runs on device
        source.set_val(Float32(1.0))
        destination.set_val(Float32(0.0))

        # Loop over tiles and enqueue Mojo kernels on AMReX's round-robin stream set.
        var mfi = destination.gpu_mfiter()
        while mfi.is_valid():
            var tile_box = mfi.tilebox()
            var src_array = source.unsafe_device_array(mfi)
            var dst_array = destination.unsafe_device_array(mfi)

            def update_tile(i: Int, j: Int, k: Int) {dst_array^, src_array^, add_value^}:
                dst_array[i, j, k] = src_array[i, j, k] + add_value

            ParallelFor(update_tile, ctx, mfi, tile_box)
            mfi.next()

        # write plotfile
        destination.write_single_level_plotfile(plotfile_path, geometry)

        # print diagnostics
        print("backend=", runtime.gpu_backend())
        print("boxes=", boxarray.size())
        print("nprocs=", runtime.nprocs())
        print("tiles=", destination.tile_count())
        print("sum=", destination.sum(0))
        runtime^.close()
    except e:
        runtime^.close()
        raise e^
