"""A close Mojo translation of AMReX HeatEquation_Simple/main.cpp.

Run from the repo root so the bundled inputs file is found:

    mojo examples/heat_equation_simple.mojo
"""

from amrex.space3d import (
    AmrexRuntime,
    Array4F64View,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParallelFor,
    ParmParse,
    RealVect3D,
    box3d,
    intvect3d,
    realbox3d,
)
from std.collections import List
from std.math import exp


@fieldwise_init
struct InitializeContext[phi_origin: Origin[mut=True]](Copyable):
    var phi_old: Array4F64View[Self.phi_origin]
    var dx: RealVect3D


@fieldwise_init
struct AdvanceContext[
    dst_origin: Origin[mut=True],
    src_origin: Origin[mut=True],
](Copyable):
    var phi_new: Array4F64View[Self.dst_origin]
    var phi_old: Array4F64View[Self.src_origin]
    var dx: RealVect3D
    var dt: Float64


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
    var argv = List[String](length=2, fill=String(""))
    argv[0] = String("heat_equation_simple")
    argv[1] = String("examples/heat_equation_simple.inputs")
    var runtime = AmrexRuntime(argv, use_parmparse=True)

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

    var time = 0.0

    # **********************************
    # INITIALIZE DATA LOOP
    # **********************************

    var mfi = phi_old.mfiter()
    while mfi.is_valid():
        var bx = mfi.validbox()
        var phi_old_array = phi_old.array(mfi)
        var init_ctx = InitializeContext(
            phi_old=phi_old_array.copy(),
            dx=dx.copy(),
        )

        @parameter
        def initialize_cell(
            ctx: type_of(init_ctx), i: Int, j: Int, k: Int
        ) raises:
            var x = (Float64(i) + 0.5) * ctx.dx.x
            var y = (Float64(j) + 0.5) * ctx.dx.y
            var z = (Float64(k) + 0.5) * ctx.dx.z
            var rsquared = (
                (x - 0.5) * (x - 0.5)
                + (y - 0.5) * (y - 0.5)
                + (z - 0.5) * (z - 0.5)
            ) / 0.01
            ctx.phi_old[i, j, k] = 1.0 + exp(-rsquared)

        ParallelFor[body=initialize_cell](bx, init_ctx)
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

        var update_mfi = phi_old.mfiter()
        while update_mfi.is_valid():
            var bx = update_mfi.validbox()
            var phi_old_array = phi_old.array(update_mfi)
            var phi_new_array = phi_new.array(update_mfi)
            var advance_ctx = AdvanceContext(
                phi_new=phi_new_array.copy(),
                phi_old=phi_old_array.copy(),
                dx=dx.copy(),
                dt=dt,
            )

            @parameter
            def advance_cell(
                ctx: type_of(advance_ctx), i: Int, j: Int, k: Int
            ) raises:
                ctx.phi_new[i, j, k] = ctx.phi_old[i, j, k] + ctx.dt * (
                    (
                        ctx.phi_old[i + 1, j, k]
                        - 2.0 * ctx.phi_old[i, j, k]
                        + ctx.phi_old[i - 1, j, k]
                    )
                    / (ctx.dx.x * ctx.dx.x)
                    + (
                        ctx.phi_old[i, j + 1, k]
                        - 2.0 * ctx.phi_old[i, j, k]
                        + ctx.phi_old[i, j - 1, k]
                    )
                    / (ctx.dx.y * ctx.dx.y)
                    + (
                        ctx.phi_old[i, j, k + 1]
                        - 2.0 * ctx.phi_old[i, j, k]
                        + ctx.phi_old[i, j, k - 1]
                    )
                    / (ctx.dx.z * ctx.dx.z)
                )

            ParallelFor[body=advance_cell](bx, advance_ctx)
            update_mfi.next()

        time = time + dt
        phi_old.copy_from(phi_new, 0, 0, 1)

        if runtime.ioprocessor():
            print("Advanced step ", step)

        if plot_int > 0 and step % plot_int == 0:
            phi_new.write_single_level_plotfile(
                plotfile_name(step),
                geometry,
                time,
                step,
            )
