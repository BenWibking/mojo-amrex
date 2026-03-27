"""A close GPU-interop Mojo translation of AMReX HeatEquation_Simple/main.cpp.

This mirrors the cell-local updates in
`examples/HeatEquation/heat_equation_simple.mojo`, but launches them as Mojo
GPU kernels directly over AMReX-managed device storage.

Run from the repo root so the bundled inputs file is found:

    mojo examples/HeatEquation/heat_equation_gpu_interop.mojo
"""

from amrex.space3d import (
    AmrexRuntime,
    Array4F64View,
    Box3D,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParmParse,
    box3d,
    intvect3d,
    realbox3d,
)
from std.collections import List
from std.gpu import global_idx
from std.gpu.host import DeviceContext, DeviceStream
from std.math import ceildiv, exp
from std.sys import has_accelerator


comptime KERNEL_BLOCK_SIZE = 256


def cell_count(box: Box3D) -> Int:
    return (
        (Int(box.big_end.x) - Int(box.small_end.x) + 1)
        * (Int(box.big_end.y) - Int(box.small_end.y) + 1)
        * (Int(box.big_end.z) - Int(box.small_end.z) + 1)
    )


def initialize_tile_gpu(
    phi_old: Array4F64View[MutAnyOrigin],
    tile_box: Box3D,
    dx_x: Float64,
    dx_y: Float64,
    dx_z: Float64,
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

        var x = (Float64(i) + 0.5) * dx_x
        var y = (Float64(j) + 0.5) * dx_y
        var z = (Float64(k) + 0.5) * dx_z
        var rsquared = (
            (x - 0.5) * (x - 0.5)
            + (y - 0.5) * (y - 0.5)
            + (z - 0.5) * (z - 0.5)
        ) / 0.01
        phi_old[i, j, k] = 1.0 + exp(-rsquared)


def advance_tile_gpu(
    phi_new: Array4F64View[MutAnyOrigin],
    phi_old: Array4F64View[MutAnyOrigin],
    tile_box: Box3D,
    dx_x: Float64,
    dx_y: Float64,
    dx_z: Float64,
    dt: Float64,
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

        phi_new[i, j, k] = phi_old[i, j, k] + dt * (
            (
                phi_old[i + 1, j, k]
                - 2.0 * phi_old[i, j, k]
                + phi_old[i - 1, j, k]
            )
            / (dx_x * dx_x)
            + (
                phi_old[i, j + 1, k]
                - 2.0 * phi_old[i, j, k]
                + phi_old[i, j - 1, k]
            )
            / (dx_y * dx_y)
            + (
                phi_old[i, j, k + 1]
                - 2.0 * phi_old[i, j, k]
                + phi_old[i, j, k - 1]
            )
            / (dx_z * dx_z)
        )


def current_amrex_stream(
    ref runtime: AmrexRuntime, ref ctx: DeviceContext
) raises -> DeviceStream:
    return ctx.create_external_stream(runtime.gpu_stream_handle())


def require_direct_gpu_interop(
    ref runtime: AmrexRuntime, ref multifab: MultiFab
) raises:
    if runtime.gpu_backend() == "none":
        raise Error(
            "examples/HeatEquation/heat_equation_gpu_interop.mojo requires"
            " AMReX built with CUDA or HIP support."
        )

    if not has_accelerator():
        raise Error(
            "examples/HeatEquation/heat_equation_gpu_interop.mojo requires"
            " a Mojo-supported accelerator."
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


def plotfile_name(step: Int) -> String:
    if step < 10:
        return String.write(t"plt0000{step}")
    if step < 100:
        return String.write(t"plt000{step}")
    if step < 1000:
        return String.write(t"plt00{step}")
    if step < 10000:
        return String.write(t"plt0{step}")
    return String.write(t"plt{step}")


def main() raises:
    var ctx = DeviceContext()

    var argv = List[String](length=2, fill=String(""))
    argv[0] = String("heat_equation_gpu")
    argv[1] = String("examples/HeatEquation/heat_equation_gpu.inputs")
    var runtime = AmrexRuntime(Int(ctx.id()), argv, use_parmparse=True)
    try:
        # **********************************
        # DECLARE SIMULATION PARAMETERS
        # **********************************

        var params = ParmParse(runtime)

        var n_cell = params.get_int("n_cell")
        var max_grid_size = params.get_int("max_grid_size")
        var nsteps = params.query_int_or("nsteps", 10)
        var plot_int = params.query_int_or("plot_int", -1)
        var dt = params.get_real("dt")

        # **********************************
        # DEFINE SIMULATION SETUP AND GEOMETRY
        # **********************************

        var dom_lo = intvect3d(0, 0, 0)
        var dom_hi = intvect3d(n_cell - 1, n_cell - 1, n_cell - 1)
        var domain = box3d(dom_lo, dom_hi)

        var boxarray = BoxArray(runtime, domain)
        boxarray.max_size(max_grid_size)

        var real_box = realbox3d(0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
        var is_periodic = intvect3d(1, 1, 1)
        var geometry = Geometry(runtime, domain, real_box, is_periodic)
        var dx = geometry.cell_size()

        var nghost = 1
        var ncomp = 1

        var distmap = DistributionMapping(runtime, boxarray)
        var phi_old = MultiFab(
            runtime,
            boxarray,
            distmap,
            ncomp,
            intvect3d(nghost, nghost, nghost),
        )
        var phi_new = MultiFab(
            runtime,
            boxarray,
            distmap,
            ncomp,
            intvect3d(nghost, nghost, nghost),
        )

        require_direct_gpu_interop(runtime, phi_old)
        require_direct_gpu_interop(runtime, phi_new)

        var time = 0.0

        var initialize_tile_kernel = ctx.compile_function[
            initialize_tile_gpu, initialize_tile_gpu
        ]()
        var advance_tile_kernel = ctx.compile_function[
            advance_tile_gpu, advance_tile_gpu
        ]()
        var amrex_stream = current_amrex_stream(runtime, ctx)

        # **********************************
        # INITIALIZE DATA LOOP
        # **********************************

        var mfi = phi_old.mfiter()
        while mfi.is_valid():
            var bx = mfi.validbox()
            var phi_old_array = phi_old.unsafe_device_array(mfi)
            amrex_stream.enqueue_function(
                initialize_tile_kernel,
                phi_old_array,
                bx,
                dx.x,
                dx.y,
                dx.z,
                grid_dim=ceildiv(cell_count(bx), KERNEL_BLOCK_SIZE),
                block_dim=KERNEL_BLOCK_SIZE,
            )
            mfi.next()

        # **********************************
        # WRITE INITIAL PLOT FILE
        # **********************************

        if plot_int > 0:
            amrex_stream.synchronize()
            phi_old.write_single_level_plotfile(
                plotfile_name(0),
                geometry,
                time,
                0,
            )

        # **********************************
        # MAIN TIME EVOLUTION LOOP
        # **********************************

        for step in range(1, nsteps + 1):
            phi_old.fill_boundary(geometry)
            amrex_stream = current_amrex_stream(runtime, ctx)

            var update_mfi = phi_old.mfiter()
            while update_mfi.is_valid():
                var bx = update_mfi.validbox()
                var phi_old_array = phi_old.unsafe_device_array(update_mfi)
                var phi_new_array = phi_new.unsafe_device_array(update_mfi)
                amrex_stream.enqueue_function(
                    advance_tile_kernel,
                    phi_new_array,
                    phi_old_array,
                    bx,
                    dx.x,
                    dx.y,
                    dx.z,
                    dt,
                    grid_dim=ceildiv(cell_count(bx), KERNEL_BLOCK_SIZE),
                    block_dim=KERNEL_BLOCK_SIZE,
                )
                update_mfi.next()

            time = time + dt
            amrex_stream.synchronize()  # needed to make sure phi_new is ready before copying back to phi_old
            phi_old.copy_from(phi_new, 0, 0, 1)

            if runtime.ioprocessor():
                print("Advanced step ", step)

            if plot_int > 0 and step % plot_int == 0:
                amrex_stream.synchronize()
                phi_new.write_single_level_plotfile(
                    plotfile_name(step),
                    geometry,
                    time,
                    step,
                )

        amrex_stream.synchronize()  # prevents host-visible teardown before kernels finish
        runtime^.close()
    except e:
        runtime^.close()
        raise e^
