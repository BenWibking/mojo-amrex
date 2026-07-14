# ABOUTME: Heat equation example translated from AMReX HeatEquation_EX1_C.
# ABOUTME: Reads parameters, initializes data, and advances in time.

"""A close Mojo translation of AMReX HeatEquation_EX1_C.

Run from the repo root so the bundled inputs file is found:

    mojo examples/HeatEquation/heat_equation.mojo
"""

from amrex.space3d import (
    AmrexFloat64,
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParmInt,
    ParmParse,
    ParmReal,
    box3d,
    convert,
    intvect3d,
    realbox3d,
)
from std.collections import List
from std.math import exp


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
    argv[0] = String("heat_equation")
    argv[1] = String("examples/HeatEquation/heat_equation.inputs")

    var runtime = AmrexRuntime(argv, use_parmparse=True)

    try:
        # **********************************
        # DECLARE SIMULATION PARAMETERS
        # **********************************

        var params = ParmParse(runtime)

        var n_cell = params.get[ParmInt]("n_cell")
        var max_grid_size = params.get[ParmInt]("max_grid_size")
        var nsteps = params.query_or[ParmInt]("nsteps", 10)
        var plot_int = params.query_or[ParmInt]("plot_int", -1)
        var dt = params.get[ParmReal]("dt")

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
        var distmap = DistributionMapping(runtime, boxarray)

        var xflux_boxarray = convert(boxarray, intvect3d(1, 0, 0))
        var yflux_boxarray = convert(boxarray, intvect3d(0, 1, 0))
        var zflux_boxarray = convert(boxarray, intvect3d(0, 0, 1))

        var phi_old = MultiFab[AmrexFloat64](
            runtime,
            boxarray,
            distmap,
            1,
            intvect3d(1, 1, 1),
        )
        var phi_new = MultiFab[AmrexFloat64](
            runtime,
            boxarray,
            distmap,
            1,
            intvect3d(1, 1, 1),
        )
        var flux_x = MultiFab[AmrexFloat64](
            runtime,
            xflux_boxarray,
            distmap,
            1,
            intvect3d(0, 0, 0),
        )
        var flux_y = MultiFab[AmrexFloat64](
            runtime,
            yflux_boxarray,
            distmap,
            1,
            intvect3d(0, 0, 0),
        )
        var flux_z = MultiFab[AmrexFloat64](
            runtime,
            zflux_boxarray,
            distmap,
            1,
            intvect3d(0, 0, 0),
        )

        var time = 0.0

        # **********************************
        # INITIALIZE DATA LOOP
        # **********************************

        var mfi = phi_old.mfiter()
        for tile in mfi:
            var bx = tile.valid_box
            var phi_old_arr = phi_old.array(mfi)
            var dx = geometry.cell_size()

            def initialize_cell(
                i: Int, j: Int, k: Int
            ) {var phi_old_arr^, var dx}:
                var x = (Float64(i) + 0.5) * dx.x
                var y = (Float64(j) + 0.5) * dx.y
                var z = (Float64(k) + 0.5) * dx.z
                var rsquared = (
                    (x - 0.5) * (x - 0.5)
                    + (y - 0.5) * (y - 0.5)
                    + (z - 0.5) * (z - 0.5)
                ) / 0.01
                phi_old_arr[i, j, k] = 1.0 + exp(-rsquared)

            mfi.parallel_for(initialize_cell, bx)

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

            var dx = geometry.cell_size()
            var dxinv = 1.0 / dx.x
            var dyinv = 1.0 / dx.y
            var dzinv = 1.0 / dx.z

            # One tile loop dispatches all four device kernels per tile. The flux
            # boxes for a tile exactly cover that tile's own cell faces, so the
            # advance kernel only consumes flux values computed on the same tile.
            var mfi = phi_old.mfiter()

            for tile in mfi:
                var phi_old_arr = phi_old.array(mfi)
                var phi_new_arr = phi_new.array(mfi)
                var flux_x_arr = flux_x.array(mfi)
                var flux_y_arr = flux_y.array(mfi)
                var flux_z_arr = flux_z.array(mfi)

                ## compute fluxes on this tile

                def compute_flux_x(
                    i: Int, j: Int, k: Int
                ) {var flux_x_arr^, var phi_old_arr^, var dxinv}:
                    flux_x_arr[i, j, k] = (
                        phi_old_arr[i, j, k] - phi_old_arr[i - 1, j, k]
                    ) * dxinv

                mfi.parallel_for(compute_flux_x, tile.valid_box)

                def compute_flux_y(
                    i: Int, j: Int, k: Int
                ) {var flux_y_arr^, var phi_old_arr^, var dyinv}:
                    flux_y_arr[i, j, k] = (
                        phi_old_arr[i, j, k] - phi_old_arr[i, j - 1, k]
                    ) * dyinv

                mfi.parallel_for(compute_flux_y, tile.valid_box)

                def compute_flux_z(
                    i: Int, j: Int, k: Int
                ) {var flux_z_arr^, var phi_old_arr^, var dzinv}:
                    flux_z_arr[i, j, k] = (
                        phi_old_arr[i, j, k] - phi_old_arr[i, j, k - 1]
                    ) * dzinv

                mfi.parallel_for(compute_flux_z, tile.valid_box)

                ## update phi on this tile

                def advance_cell(
                    i: Int, j: Int, k: Int
                ) {
                    var phi_new_arr^,
                    var phi_old_arr^,
                    var flux_x_arr^,
                    var flux_y_arr^,
                    var flux_z_arr^,
                    var dxinv,
                    var dyinv,
                    var dzinv,
                    var dt,
                }:
                    phi_new_arr[i, j, k] = (
                        phi_old_arr[i, j, k]
                        + dt
                        * dxinv
                        * (flux_x_arr[i + 1, j, k] - flux_x_arr[i, j, k])
                        + dt
                        * dyinv
                        * (flux_y_arr[i, j + 1, k] - flux_y_arr[i, j, k])
                        + dt
                        * dzinv
                        * (flux_z_arr[i, j, k + 1] - flux_z_arr[i, j, k])
                    )

                mfi.parallel_for(advance_cell, tile.valid_box)

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
