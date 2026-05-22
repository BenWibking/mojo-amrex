"""`MultiFab` and `Array4` wrappers for the 3D binding layer."""

from amrex.ffi import (
    Array4View,
    Box3D,
    GPU_BACKEND_NONE,
    IntVect3D,
    MFIterHandle,
    MultiFabMemoryInfo,
    MultiFabHandle,
    OptionalMultiFabHandle,
    TileView,
    device_array4_view_from_mfiter,
    device_array4_view_from_mfiter_as_origin,
    gpu_backend,
    array4_view_from_mfiter,
    last_error_message,
    multifab_copy,
    multifab_create,
    multifab_fill_boundary,
    multifab_max,
    multifab_memory_info,
    multifab_min,
    multifab_mult,
    multifab_ncomp,
    multifab_norm0,
    multifab_norm1,
    multifab_norm2,
    multifab_parallel_copy,
    multifab_plus,
    multifab_set_val,
    multifab_sum,
    multifab_tile_count,
    multifab_tile_box,
    multifab_valid_box,
    multifab_write_single_level_plotfile,
    raise_on_error,
)
from amrex.floating_dtype import AmrexFloatingDtype
from amrex.ownership import AmrexHandle, AmrexRawHandle, destroy_amrex_optional_handle
from amrex.runtime import AmrexRuntime, RuntimeLease
from amrex.space3d.boxarray import BoxArray, DistributionMapping
from amrex.space3d.geometry import Geometry
from amrex.space3d.mfiter import (
    MFIter,
    MFIterRange,
    create_gpu_mfiter,
    create_mfiter,
    create_mfiter_range,
)
from std.ffi import OwnedDLHandle


trait MultiFabScalarOp:
    @staticmethod
    def apply(
        ref lib: OwnedDLHandle,
        handle: MultiFabHandle,
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D,
    ) raises -> Int:
        ...


struct MultiFabSetValOp(MultiFabScalarOp):
    @staticmethod
    def apply(
        ref lib: OwnedDLHandle,
        handle: MultiFabHandle,
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D,
    ) raises -> Int:
        return multifab_set_val(lib, handle, value, start_comp, ncomp)


struct MultiFabPlusOp(MultiFabScalarOp):
    @staticmethod
    def apply(
        ref lib: OwnedDLHandle,
        handle: MultiFabHandle,
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D,
    ) raises -> Int:
        return multifab_plus(lib, handle, value, start_comp, ncomp, ngrow)


struct MultiFabMultOp(MultiFabScalarOp):
    @staticmethod
    def apply(
        ref lib: OwnedDLHandle,
        handle: MultiFabHandle,
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D,
    ) raises -> Int:
        return multifab_mult(lib, handle, value, start_comp, ncomp, ngrow)


struct MultiFab[T: AmrexFloatingDtype](AmrexHandle, Movable):
    comptime dtype = Self.T.dtype
    comptime value_type = Scalar[Self.dtype]
    comptime moved_from_message = "MultiFab no longer owns a live AMReX handle. The value may have been moved from."
    comptime destroy_symbol = "amrex_mojo_multifab_destroy"

    var runtime: RuntimeLease
    var handle: OptionalMultiFabHandle
    var ngrow_vect: IntVect3D

    @staticmethod
    def _datatype_id() -> Int:
        return Self.T.multifab_datatype_id

    def __init__(
        out self,
        ref runtime: AmrexRuntime,
        ref boxarray: BoxArray,
        ref distmap: DistributionMapping,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        self.runtime = runtime._lease()
        self.handle = multifab_create(
            self.runtime[].lib,
            self.runtime[].handle,
            boxarray._handle(),
            distmap._handle(),
            ncomp,
            ngrow,
            Self._datatype_id(),
        )
        self.ngrow_vect = ngrow.copy()
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __del__(deinit self):
        destroy_amrex_optional_handle[Self.destroy_symbol](self.runtime[].lib, self.handle)

    def _optional_handle(ref self) -> Optional[AmrexRawHandle]:
        return self.handle

    def ncomp(ref self) raises -> Int:
        var handle = self._handle()
        return multifab_ncomp(self.runtime[].lib, handle)

    def ngrow(ref self) raises -> IntVect3D:
        return self.ngrow_vect.copy()

    def memory_info(ref self) raises -> MultiFabMemoryInfo:
        var handle = self._handle()
        return multifab_memory_info(self.runtime[].lib, handle)

    def _use_device_array(ref self) raises -> Bool:
        return gpu_backend(self.runtime[].lib) != GPU_BACKEND_NONE

    def _apply_scalar_op[
        Op: MultiFabScalarOp
    ](mut self, value: Self.value_type, start_comp: Int, ncomp: Int, ngrow: IntVect3D,) raises:
        var handle = self._handle()
        raise_on_error(
            self.runtime[].lib,
            Op.apply(
                self.runtime[].lib,
                handle,
                Float64(value),
                start_comp,
                ncomp,
                ngrow,
            ),
        )

    def set_val(mut self, value: Self.value_type, start_comp: Int, ncomp: Int) raises:
        self._apply_scalar_op[MultiFabSetValOp](value, start_comp, ncomp, IntVect3D(x=0, y=0, z=0))

    def set_val(mut self, value: Self.value_type) raises:
        self.set_val(value, 0, self.ncomp())

    def tile_count(ref self) raises -> Int:
        var handle = self._handle()
        return multifab_tile_count(self.runtime[].lib, handle)

    def tile_box(ref self, tile_index: Int) raises -> Box3D:
        self._require_tile_index(tile_index)
        return multifab_tile_box(self.runtime[].lib, self._handle(), tile_index)

    def valid_box(ref self, tile_index: Int) raises -> Box3D:
        self._require_tile_index(tile_index)
        return multifab_valid_box(self.runtime[].lib, self._handle(), tile_index)

    def mfiter(ref self) raises -> MFIter:
        var handle = self._handle()
        return create_mfiter(
            self.runtime,
            handle,
            self.ngrow_vect,
            self._use_device_array(),
        )

    def gpu_mfiter(ref self) raises -> MFIter:
        var handle = self._handle()
        return create_gpu_mfiter(
            self.runtime,
            handle,
            self.ngrow_vect,
            self._use_device_array(),
        )

    def tiles(ref self) raises -> MFIterRange:
        var handle = self._handle()
        return create_mfiter_range(
            self.runtime,
            handle,
            self.ngrow_vect,
            self._use_device_array(),
        )

    def array[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: MFIter) raises -> Array4View[Self.T, owner_origin]:
        return self.tile(mfi).array()

    def unsafe_device_array(ref self, ref mfi: MFIter) raises -> Array4View[Self.T, MutAnyOrigin]:
        var handle = self._handle()
        return device_array4_view_from_mfiter[Self.T](self.runtime[].lib, handle, mfi._handle())

    def tile[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: MFIter) raises -> TileView[Self.T, owner_origin]:
        var handle = self._handle()
        var tile_box = mfi.tilebox()
        var valid_box = mfi.validbox()
        var array_view = self._array_for_mfiter[owner_origin](handle, mfi._handle())
        return TileView[Self.T, owner_origin](
            tile_box=tile_box,
            valid_box=valid_box,
            array_view=array_view.copy(),
        )

    def for_each_tile[
        tile_func: def[borrow_origin: Origin[mut=True]](TileView[Self.T, borrow_origin]) raises thin -> None
    ](mut self) raises:
        var mfi = self.mfiter()
        while mfi.is_valid():
            tile_func(self.tile(mfi))
            mfi.next()

    def _array_for_mfiter[
        owner_origin: Origin[mut=True]
    ](ref self, handle: MultiFabHandle, mfiter_handle: MFIterHandle) raises -> Array4View[Self.T, owner_origin]:
        if self._use_device_array():
            return device_array4_view_from_mfiter_as_origin[Self.T, owner_origin](
                self.runtime[].lib,
                handle,
                mfiter_handle,
            )
        return array4_view_from_mfiter[Self.T, owner_origin](
            self.runtime[].lib,
            handle,
            mfiter_handle,
        )

    def min(ref self, comp: Int) raises -> Float64:
        var handle = self._handle()
        return multifab_min(self.runtime[].lib, handle, comp)

    def max(ref self, comp: Int) raises -> Float64:
        var handle = self._handle()
        return multifab_max(self.runtime[].lib, handle, comp)

    def sum(ref self, comp: Int) raises -> Float64:
        var handle = self._handle()
        return multifab_sum(self.runtime[].lib, handle, comp)

    def norm0(ref self, comp: Int) raises -> Float64:
        var handle = self._handle()
        return multifab_norm0(self.runtime[].lib, handle, comp)

    def norm1(ref self, comp: Int) raises -> Float64:
        var handle = self._handle()
        return multifab_norm1(self.runtime[].lib, handle, comp)

    def norm2(ref self, comp: Int) raises -> Float64:
        var handle = self._handle()
        return multifab_norm2(self.runtime[].lib, handle, comp)

    def plus(
        mut self,
        value: Self.value_type,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        self._apply_scalar_op[MultiFabPlusOp](value, start_comp, ncomp, ngrow)

    def mult(
        mut self,
        value: Self.value_type,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        self._apply_scalar_op[MultiFabMultOp](value, start_comp, ncomp, ngrow)

    def copy_from(
        mut self,
        ref source: MultiFab[Self.T],
        src_comp: Int,
        dst_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        raise_on_error(
            self.runtime[].lib,
            multifab_copy(
                self.runtime[].lib,
                handle,
                source._handle(),
                src_comp,
                dst_comp,
                ncomp,
                ngrow,
            ),
        )

    def parallel_copy_from(
        mut self,
        ref source: MultiFab[Self.T],
        ref geometry: Geometry,
        src_comp: Int,
        dst_comp: Int,
        ncomp: Int,
        src_ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
        dst_ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        raise_on_error(
            self.runtime[].lib,
            multifab_parallel_copy(
                self.runtime[].lib,
                handle,
                source._handle(),
                geometry._handle(),
                src_comp,
                dst_comp,
                ncomp,
                src_ngrow,
                dst_ngrow,
            ),
        )

    def fill_boundary(
        mut self,
        ref geometry: Geometry,
        start_comp: Int,
        ncomp: Int,
        cross: Bool = False,
    ) raises:
        var handle = self._handle()
        raise_on_error(
            self.runtime[].lib,
            multifab_fill_boundary(
                self.runtime[].lib,
                handle,
                geometry._handle(),
                start_comp,
                ncomp,
                cross,
            ),
        )

    def fill_boundary(mut self, ref geometry: Geometry, cross: Bool = False) raises:
        self.fill_boundary(geometry, 0, self.ncomp(), cross)

    def write_single_level_plotfile(
        ref self,
        plotfile: String,
        ref geometry: Geometry,
        time: Float64 = 0.0,
        level_step: Int = 0,
    ) raises:
        var handle = self._handle()
        raise_on_error(
            self.runtime[].lib,
            multifab_write_single_level_plotfile(
                self.runtime[].lib,
                handle,
                geometry._handle(),
                plotfile,
                time,
                level_step,
            ),
        )

    def write_single_level_plotfile(
        ref self,
        plotfile: StringLiteral,
        ref geometry: Geometry,
        time: Float64 = 0.0,
        level_step: Int = 0,
    ) raises:
        self.write_single_level_plotfile(
            String(plotfile),
            geometry,
            time,
            level_step,
        )

    def _require_tile_index(ref self, tile_index: Int) raises:
        if tile_index < 0 or tile_index >= self.tile_count():
            raise Error("tile index is out of range.")
