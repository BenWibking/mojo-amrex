"""Notebook-friendly heat equation runner with step-wise Python control."""

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
from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder


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


def initialize_phi(mut phi_old: MultiFab, dx: RealVect3D) raises:
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


struct HeatEquationRunner(Movable, Writable):
    var runtime: AmrexRuntime
    var geometry: Geometry
    var phi_old: MultiFab
    var phi_new: MultiFab
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
            var n_cell = params.get_int("n_cell")
            var max_grid_size = params.get_int("max_grid_size")
            var nsteps = params.query_int_or("nsteps", 10)
            var dt = params.get_real("dt")

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
        var output_slice = np.zeros(
            shape=Python.tuple(self.n_cell, self.n_cell)
        )
        var slice_mfi = self.phi_old.mfiter()
        while slice_mfi.is_valid():
            var bx = slice_mfi.validbox()
            if (
                self.mid_plane >= Int(bx.small_end.z)
                and self.mid_plane <= Int(bx.big_end.z)
            ):
                var phi_src = self.phi_old.array(slice_mfi)
                for j in range(Int(bx.small_end.y), Int(bx.big_end.y) + 1):
                    for i in range(Int(bx.small_end.x), Int(bx.big_end.x) + 1):
                        output_slice[i, j] = phi_src[
                            i, j, self.mid_plane
                        ]
            slice_mfi.next()
        return output_slice

    def step(mut self) raises -> Bool:
        if self.current_step >= self.nsteps:
            return False

        self.phi_old.fill_boundary(self.geometry)

        var update_mfi = self.phi_old.mfiter()
        while update_mfi.is_valid():
            var bx = update_mfi.validbox()
            var phi_old_array = self.phi_old.array(update_mfi)
            var phi_new_array = self.phi_new.array(update_mfi)
            var advance_ctx = AdvanceContext(
                phi_new=phi_new_array.copy(),
                phi_old=phi_old_array.copy(),
                dx=self.dx.copy(),
                dt=self.dt,
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
    def step_py(
        self_ptr: UnsafePointer[Self, MutAnyOrigin]
    ) raises -> PythonObject:
        return PythonObject(self_ptr[].step())

    @staticmethod
    def slice_array_py(
        self_ptr: UnsafePointer[Self, MutAnyOrigin],
    ) raises -> PythonObject:
        return self_ptr[].slice_array()

    @staticmethod
    def current_step_py(
        self_ptr: UnsafePointer[Self, MutAnyOrigin]
    ) -> PythonObject:
        return PythonObject(self_ptr[].current_step)

    @staticmethod
    def nsteps_py(
        self_ptr: UnsafePointer[Self, MutAnyOrigin]
    ) -> PythonObject:
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
