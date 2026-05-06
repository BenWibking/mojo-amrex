"""A close GPU-interop Mojo translation of AMReX HeatEquation_Simple/main.cpp.

This mirrors the cell-local updates in
`examples/HeatEquation/heat_equation_simple.mojo`, but launches them as Mojo
GPU kernels directly over AMReX-managed device storage.

Run from the repo root so the bundled inputs file is found:

    mojo examples/HeatEquation/heat_equation_gpu_interop.mojo
"""

from amrex.space3d import (
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParallelFor,
    ParmParse,
    box3d,
    intvect3d,
    realbox3d,
)
from std.collections import List
from std.gpu.host import DeviceContext
from std.math import exp
from std.sys import has_accelerator


def require_direct_gpu_interop(ref runtime: AmrexRuntime, ref multifab: MultiFab) raises:
    if runtime.gpu_backend() == "none":
        raise Error(
            "examples/HeatEquation/heat_equation_gpu_interop.mojo requires AMReX built with CUDA or HIP support."
        )

    if not has_accelerator():
        raise Error("examples/HeatEquation/heat_equation_gpu_interop.mojo requires a Mojo-supported accelerator.")

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

        # **********************************
        # INITIALIZE DATA LOOP
        # **********************************

        var mfi = phi_old.gpu_mfiter()
        while mfi.is_valid():
            var bx = mfi.validbox()
            var phi_old_array = phi_old.unsafe_device_array(mfi)
            var tile_dx = dx.copy()

            def initialize_cell(i: Int, j: Int, k: Int) {phi_old_array^, tile_dx^}:
                var x = (Float64(i) + 0.5) * tile_dx.x
                var y = (Float64(j) + 0.5) * tile_dx.y
                var z = (Float64(k) + 0.5) * tile_dx.z
                var rsquared = ((x - 0.5) * (x - 0.5) + (y - 0.5) * (y - 0.5) + (z - 0.5) * (z - 0.5)) / 0.01
                phi_old_array[i, j, k] = 1.0 + exp(-rsquared)

            ParallelFor(initialize_cell, ctx, mfi, bx)
            mfi.next()

        # **********************************
        # WRITE INITIAL PLOT FILE
        # **********************************

        if plot_int > 0:
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

            var update_mfi = phi_old.gpu_mfiter()
            while update_mfi.is_valid():
                var bx = update_mfi.validbox()
                var phi_old_array = phi_old.unsafe_device_array(update_mfi)
                var phi_new_array = phi_new.unsafe_device_array(update_mfi)
                var tile_dx = dx.copy()

                def advance_cell(
                    i: Int, j: Int, k: Int
                ) {phi_new_array^, phi_old_array^, tile_dx^, dt^}:
                    phi_new_array[i, j, k] = phi_old_array[i, j, k] + dt * (
                        (phi_old_array[i + 1, j, k] - 2.0 * phi_old_array[i, j, k] + phi_old_array[i - 1, j, k])
                        / (tile_dx.x * tile_dx.x)
                        + (phi_old_array[i, j + 1, k] - 2.0 * phi_old_array[i, j, k] + phi_old_array[i, j - 1, k])
                        / (tile_dx.y * tile_dx.y)
                        + (phi_old_array[i, j, k + 1] - 2.0 * phi_old_array[i, j, k] + phi_old_array[i, j, k - 1])
                        / (tile_dx.z * tile_dx.z)
                    )

                ParallelFor(advance_cell, ctx, update_mfi, bx)
                update_mfi.next()

            time = time + dt
            var phi_swap = phi_old^
            phi_old = phi_new^
            phi_new = phi_swap^

            if runtime.ioprocessor():
                print("Advanced step ", step)

            if plot_int > 0 and step % plot_int == 0:
                phi_old.write_single_level_plotfile(
                    plotfile_name(step),
                    geometry,
                    time,
                    step,
                )

        runtime^.close()
    except e:
        runtime^.close()
        raise e^
