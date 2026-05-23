"""Notebook-friendly heat equation runner with step-wise Python control."""

from amrex.space3d import (
    AmrexFloat64,
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParallelFor,
    ParmInt,
    ParmParse,
    ParmReal,
    RealVect3D,
    box3d,
    intvect3d,
    realbox3d,
)
from std.collections import List
from std.math import exp
from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder


def initialize_phi(mut phi_old: MultiFab[AmrexFloat64], dx: RealVect3D) raises:
    var mfi = phi_old.mfiter()
    for tile in mfi:
        var bx = tile.valid_box
        var phi_old_array = phi_old.array(mfi)
        var tile_dx = dx.copy()

        def initialize_cell(i: Int, j: Int, k: Int) {var phi_old_array^, var tile_dx}:
            var x = (Float64(i) + 0.5) * tile_dx.x
            var y = (Float64(j) + 0.5) * tile_dx.y
            var z = (Float64(k) + 0.5) * tile_dx.z
            var rsquared = ((x - 0.5) * (x - 0.5) + (y - 0.5) * (y - 0.5) + (z - 0.5) * (z - 0.5)) / 0.01
            phi_old_array[i, j, k] = 1.0 + exp(-rsquared)

        ParallelFor(initialize_cell, bx)


struct HeatEquationRunner(Movable, Writable):
    var runtime: AmrexRuntime
    var geometry: Geometry
    var phi_old: MultiFab[AmrexFloat64]
    var phi_new: MultiFab[AmrexFloat64]
    var dx: RealVect3D
    var dt: Float64
    var nsteps: Int
    var current_step: Int
    var n_cell: Int
    var mid_plane: Int

    def __init__(out self) raises:
        var argv = List[String](length=2, fill=String(""))
        argv[0] = String("heat_equation_vis")
        argv[1] = String("heat_equation.inputs")
        var runtime = AmrexRuntime(argv, use_parmparse=True)
        try:
            var params = ParmParse(runtime)
            var n_cell: Int = params.get[ParmInt]("n_cell")
            var max_grid_size: Int = params.get[ParmInt]("max_grid_size")
            var nsteps: Int = params.query_or[ParmInt]("nsteps", 10)
            var dt: Float64 = params.get[ParmReal]("dt")

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
            var phi_old = MultiFab[AmrexFloat64](
                runtime,
                boxarray,
                distmap,
                ncomp,
                intvect3d(nghost, nghost, nghost),
            )
            var phi_new = MultiFab[AmrexFloat64](
                runtime,
                boxarray,
                distmap,
                ncomp,
                intvect3d(nghost, nghost, nghost),
            )

            initialize_phi(phi_old, dx)

            self.runtime = runtime^
            self.geometry = geometry^
            self.phi_old = phi_old^
            self.phi_new = phi_new^
            self.dx = dx.copy()
            self.dt = dt
            self.nsteps = nsteps
            self.current_step = 0
            self.n_cell = n_cell
            self.mid_plane = n_cell // 2
        except e:
            runtime^.close()
            raise e^

    def __del__(deinit self):
        self.runtime^.close()

    def slice_array(mut self) raises -> PythonObject:
        var np = Python.import_module("numpy")
        var output_slice = np.zeros(shape=Python.tuple(self.n_cell, self.n_cell))
        var slice_mfi = self.phi_old.mfiter()
        for tile in slice_mfi:
            var bx = tile.valid_box
            if self.mid_plane >= Int(bx.small_end.z) and self.mid_plane <= Int(bx.big_end.z):
                var phi_src = self.phi_old.array(slice_mfi)
                for j in range(Int(bx.small_end.y), Int(bx.big_end.y) + 1):
                    for i in range(Int(bx.small_end.x), Int(bx.big_end.x) + 1):
                        output_slice[i, j] = phi_src[i, j, self.mid_plane]
        return output_slice

    def step(mut self) raises -> Bool:
        if self.current_step >= self.nsteps:
            return False

        self.phi_old.fill_boundary(self.geometry)

        var update_mfi = self.phi_old.mfiter()
        for tile in update_mfi:
            var bx = tile.valid_box
            var phi_old_array = self.phi_old.array(update_mfi)
            var phi_new_array = self.phi_new.array(update_mfi)
            var tile_dx = self.dx.copy()
            var dt = self.dt

            def advance_cell(
                i: Int, j: Int, k: Int
            ) {var phi_new_array^, var phi_old_array^, var tile_dx, var dt,}:
                phi_new_array[i, j, k] = phi_old_array[i, j, k] + dt * (
                    (phi_old_array[i + 1, j, k] - 2.0 * phi_old_array[i, j, k] + phi_old_array[i - 1, j, k])
                    / (tile_dx.x * tile_dx.x)
                    + (phi_old_array[i, j + 1, k] - 2.0 * phi_old_array[i, j, k] + phi_old_array[i, j - 1, k])
                    / (tile_dx.y * tile_dx.y)
                    + (phi_old_array[i, j, k + 1] - 2.0 * phi_old_array[i, j, k] + phi_old_array[i, j, k - 1])
                    / (tile_dx.z * tile_dx.z)
                )

            ParallelFor(advance_cell, bx)

        self.phi_old.copy_from(self.phi_new, 0, 0, 1)
        self.current_step += 1
        return True

    @staticmethod
    def py_init(
        out self: HeatEquationRunner,
        args: PythonObject,
        kwargs: PythonObject,
    ) raises:
        _ = args
        _ = kwargs
        self = Self()

    @staticmethod
    def step_py(self_ptr: UnsafePointer[Self, MutAnyOrigin]) raises -> PythonObject:
        return PythonObject(self_ptr[].step())

    @staticmethod
    def slice_array_py(
        self_ptr: UnsafePointer[Self, MutAnyOrigin],
    ) raises -> PythonObject:
        return self_ptr[].slice_array()

    @staticmethod
    def current_step_py(self_ptr: UnsafePointer[Self, MutAnyOrigin]) -> PythonObject:
        return PythonObject(self_ptr[].current_step)

    @staticmethod
    def nsteps_py(self_ptr: UnsafePointer[Self, MutAnyOrigin]) -> PythonObject:
        return PythonObject(self_ptr[].nsteps)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "HeatEquationRunner(step=",
            self.current_step,
            "/",
            self.nsteps,
            ")",
        )

    def write_repr_to(self, mut writer: Some[Writer]):
        self.write_to(writer)


@export
def PyInit_heat_equation_vis() -> PythonObject:
    try:
        var module = PythonModuleBuilder("heat_equation_vis")
        _ = (
            module.add_type[HeatEquationRunner]("HeatEquationRunner")
            .def_py_init[HeatEquationRunner.py_init]()
            .def_method[HeatEquationRunner.step_py]("step")
            .def_method[HeatEquationRunner.slice_array_py]("slice_array")
            .def_method[HeatEquationRunner.current_step_py]("current_step")
            .def_method[HeatEquationRunner.nsteps_py]("nsteps")
        )
        return module.finalize()
    except e:
        abort(String("failed to create module: ", e))
