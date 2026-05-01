"""`MultiFab` and `Array4` wrappers for the 3D binding layer."""

from amrex.ffi import (
    Array4F32View,
    Array4F64View,
    Box3D,
    IntVect3D,
    MULTIFAB_DATATYPE_FLOAT32,
    MultiFabMemoryInfo,
    MultiFabHandle,
    TileF32View,
    TileF64View,
    device_array4_view_from_mfiter,
    device_array4_view_from_mfiter_f32,
    array4_view_from_mfiter_f32,
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
)
from amrex.ownership import require_live_handle
from amrex.runtime import AmrexRuntime, RuntimeLease
from amrex.space3d.boxarray import BoxArray, DistributionMapping
from amrex.space3d.geometry import Geometry
from amrex.space3d.mfiter import (
    GpuMFIter,
    MFIter,
    create_gpu_mfiter,
    create_mfiter,
)


struct MultiFab(Movable):
    var runtime: RuntimeLease
    var handle: MultiFabHandle
    var ngrow_vect: IntVect3D

    def __init__(
        out self,
        ref runtime: AmrexRuntime,
        ref boxarray: BoxArray,
        ref distmap: DistributionMapping,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
        host_only: Bool = False,
    ) raises:
        self.runtime = runtime._lease()
        self.handle = multifab_create(
            self.runtime[].lib,
            self.runtime[].handle,
            boxarray._handle(),
            distmap._handle(),
            ncomp,
            ngrow,
            host_only,
        )
        self.ngrow_vect = ngrow.copy()
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __del__(deinit self):
        if self.handle:
            self.runtime[].lib.call["amrex_mojo_multifab_destroy"](self.handle)

    def ncomp(ref self) raises -> Int:
        var handle = self._handle()
        return multifab_ncomp(self.runtime[].lib, handle)

    def ngrow(ref self) raises -> IntVect3D:
        return self.ngrow_vect.copy()

    def memory_info(ref self) raises -> MultiFabMemoryInfo:
        var handle = self._handle()
        return multifab_memory_info(self.runtime[].lib, handle)

    def set_val(mut self, value: Float64, start_comp: Int, ncomp: Int) raises:
        var handle = self._handle()
        if (
            multifab_set_val(
                self.runtime[].lib, handle, value, start_comp, ncomp
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def set_val(mut self, value: Float64) raises:
        self.set_val(value, 0, self.ncomp())

    def tile_count(ref self) raises -> Int:
        var handle = self._handle()
        return multifab_tile_count(self.runtime[].lib, handle)

    def tile_box(ref self, tile_index: Int) raises -> Box3D:
        self._require_tile_index(tile_index)
        return multifab_tile_box(self.runtime[].lib, self._handle(), tile_index)

    def valid_box(ref self, tile_index: Int) raises -> Box3D:
        self._require_tile_index(tile_index)
        return multifab_valid_box(
            self.runtime[].lib, self._handle(), tile_index
        )

    def mfiter(ref self) raises -> MFIter:
        var handle = self._handle()
        return create_mfiter(
            self.runtime,
            handle,
            self.ngrow_vect,
        )

    def gpu_mfiter(ref self) raises -> GpuMFIter:
        var handle = self._handle()
        return create_gpu_mfiter(
            self.runtime,
            handle,
            self.ngrow_vect,
        )

    def array[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: MFIter) raises -> Array4F64View[
        owner_origin
    ]:
        return self.tile(mfi).array()

    def array[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: GpuMFIter) raises -> Array4F64View[
        owner_origin
    ]:
        return self.tile(mfi).array()

    def unsafe_device_array(
        ref self, ref mfi: MFIter
    ) raises -> Array4F64View[MutAnyOrigin]:
        var handle = self._handle()
        var array_view = device_array4_view_from_mfiter(
            self.runtime[].lib, handle, mfi._handle()
        )
        if not array_view.data:
            raise Error(last_error_message(self.runtime[].lib))
        return array_view.copy()

    def unsafe_device_array(
        ref self, ref mfi: GpuMFIter
    ) raises -> Array4F64View[MutAnyOrigin]:
        var handle = self._handle()
        var array_view = device_array4_view_from_mfiter(
            self.runtime[].lib, handle, mfi._handle()
        )
        if not array_view.data:
            raise Error(last_error_message(self.runtime[].lib))
        return array_view.copy()

    def tile[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: MFIter) raises -> TileF64View[
        owner_origin
    ]:
        var handle = self._handle()
        var tile_box = mfi.tilebox()
        var valid_box = mfi.validbox()
        var array_view = array4_view_from_mfiter[owner_origin](
            self.runtime[].lib,
            handle,
            mfi._handle(),
        )
        if not array_view.data:
            raise Error(last_error_message(self.runtime[].lib))
        return TileF64View[owner_origin](
            tile_box=tile_box,
            valid_box=valid_box,
            array_view=array_view.copy(),
        )

    def tile[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: GpuMFIter) raises -> TileF64View[
        owner_origin
    ]:
        var handle = self._handle()
        var tile_box = mfi.tilebox()
        var valid_box = mfi.validbox()
        var array_view = array4_view_from_mfiter[owner_origin](
            self.runtime[].lib,
            handle,
            mfi._handle(),
        )
        if not array_view.data:
            raise Error(last_error_message(self.runtime[].lib))
        return TileF64View[owner_origin](
            tile_box=tile_box,
            valid_box=valid_box,
            array_view=array_view.copy(),
        )

    def for_each_tile[
        tile_func: def[borrow_origin: Origin[mut=True]](
            TileF64View[borrow_origin]
        ) raises thin -> None
    ](mut self) raises:
        var mfi = self.mfiter()
        while mfi.is_valid():
            tile_func(self.tile(mfi))
            mfi.next()

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
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        if (
            multifab_plus(
                self.runtime[].lib,
                handle,
                value,
                start_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def mult(
        mut self,
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        if (
            multifab_mult(
                self.runtime[].lib,
                handle,
                value,
                start_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def copy_from(
        mut self,
        ref source: MultiFab,
        src_comp: Int,
        dst_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        if (
            multifab_copy(
                self.runtime[].lib,
                handle,
                source._handle(),
                src_comp,
                dst_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def parallel_copy_from(
        mut self,
        ref source: MultiFab,
        ref geometry: Geometry,
        src_comp: Int,
        dst_comp: Int,
        ncomp: Int,
        src_ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
        dst_ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        if (
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
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def fill_boundary(
        mut self,
        ref geometry: Geometry,
        start_comp: Int,
        ncomp: Int,
        cross: Bool = False,
    ) raises:
        var handle = self._handle()
        if (
            multifab_fill_boundary(
                self.runtime[].lib,
                handle,
                geometry._handle(),
                start_comp,
                ncomp,
                cross,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def fill_boundary(
        mut self, ref geometry: Geometry, cross: Bool = False
    ) raises:
        self.fill_boundary(geometry, 0, self.ncomp(), cross)

    def write_single_level_plotfile(
        ref self,
        plotfile: String,
        ref geometry: Geometry,
        time: Float64 = 0.0,
        level_step: Int = 0,
    ) raises:
        var handle = self._handle()
        if (
            multifab_write_single_level_plotfile(
                self.runtime[].lib,
                handle,
                geometry._handle(),
                plotfile,
                time,
                level_step,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

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

    def _handle(ref self) raises -> MultiFabHandle:
        require_live_handle(
            self.handle,
            (
                "MultiFab no longer owns a live AMReX handle. The value may"
                " have been moved from."
            ),
        )
        return self.handle


struct MultiFabF32(Movable):
    var runtime: RuntimeLease
    var handle: MultiFabHandle
    var ngrow_vect: IntVect3D

    def __init__(
        out self,
        ref runtime: AmrexRuntime,
        ref boxarray: BoxArray,
        ref distmap: DistributionMapping,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
        host_only: Bool = False,
    ) raises:
        self.runtime = runtime._lease()
        self.handle = multifab_create(
            self.runtime[].lib,
            self.runtime[].handle,
            boxarray._handle(),
            distmap._handle(),
            ncomp,
            ngrow,
            host_only,
            MULTIFAB_DATATYPE_FLOAT32,
        )
        self.ngrow_vect = ngrow.copy()
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __del__(deinit self):
        if self.handle:
            self.runtime[].lib.call["amrex_mojo_multifab_destroy"](self.handle)

    def ncomp(ref self) raises -> Int:
        var handle = self._handle()
        return multifab_ncomp(self.runtime[].lib, handle)

    def ngrow(ref self) raises -> IntVect3D:
        return self.ngrow_vect.copy()

    def memory_info(ref self) raises -> MultiFabMemoryInfo:
        var handle = self._handle()
        return multifab_memory_info(self.runtime[].lib, handle)

    def set_val(mut self, value: Float32, start_comp: Int, ncomp: Int) raises:
        var handle = self._handle()
        if (
            multifab_set_val(
                self.runtime[].lib, handle, Float64(value), start_comp, ncomp
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def set_val(mut self, value: Float32) raises:
        self.set_val(value, 0, self.ncomp())

    def tile_count(ref self) raises -> Int:
        var handle = self._handle()
        return multifab_tile_count(self.runtime[].lib, handle)

    def tile_box(ref self, tile_index: Int) raises -> Box3D:
        self._require_tile_index(tile_index)
        return multifab_tile_box(self.runtime[].lib, self._handle(), tile_index)

    def valid_box(ref self, tile_index: Int) raises -> Box3D:
        self._require_tile_index(tile_index)
        return multifab_valid_box(
            self.runtime[].lib, self._handle(), tile_index
        )

    def mfiter(ref self) raises -> MFIter:
        var handle = self._handle()
        return create_mfiter(
            self.runtime,
            handle,
            self.ngrow_vect,
        )

    def gpu_mfiter(ref self) raises -> GpuMFIter:
        var handle = self._handle()
        return create_gpu_mfiter(
            self.runtime,
            handle,
            self.ngrow_vect,
        )

    def array[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: MFIter) raises -> Array4F32View[
        owner_origin
    ]:
        return self.tile(mfi).array()

    def array[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: GpuMFIter) raises -> Array4F32View[
        owner_origin
    ]:
        return self.tile(mfi).array()

    def unsafe_device_array(
        ref self, ref mfi: MFIter
    ) raises -> Array4F32View[MutAnyOrigin]:
        var handle = self._handle()
        var array_view = device_array4_view_from_mfiter_f32(
            self.runtime[].lib, handle, mfi._handle()
        )
        if not array_view.data:
            raise Error(last_error_message(self.runtime[].lib))
        return array_view.copy()

    def unsafe_device_array(
        ref self, ref mfi: GpuMFIter
    ) raises -> Array4F32View[MutAnyOrigin]:
        var handle = self._handle()
        var array_view = device_array4_view_from_mfiter_f32(
            self.runtime[].lib, handle, mfi._handle()
        )
        if not array_view.data:
            raise Error(last_error_message(self.runtime[].lib))
        return array_view.copy()

    def tile[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: MFIter) raises -> TileF32View[
        owner_origin
    ]:
        var handle = self._handle()
        var tile_box = mfi.tilebox()
        var valid_box = mfi.validbox()
        var array_view = array4_view_from_mfiter_f32[owner_origin](
            self.runtime[].lib,
            handle,
            mfi._handle(),
        )
        if not array_view.data:
            raise Error(last_error_message(self.runtime[].lib))
        return TileF32View[owner_origin](
            tile_box=tile_box,
            valid_box=valid_box,
            array_view=array_view.copy(),
        )

    def tile[
        owner_origin: Origin[mut=True]
    ](ref[owner_origin] self, ref mfi: GpuMFIter) raises -> TileF32View[
        owner_origin
    ]:
        var handle = self._handle()
        var tile_box = mfi.tilebox()
        var valid_box = mfi.validbox()
        var array_view = array4_view_from_mfiter_f32[owner_origin](
            self.runtime[].lib,
            handle,
            mfi._handle(),
        )
        if not array_view.data:
            raise Error(last_error_message(self.runtime[].lib))
        return TileF32View[owner_origin](
            tile_box=tile_box,
            valid_box=valid_box,
            array_view=array_view.copy(),
        )

    def for_each_tile[
        tile_func: def[borrow_origin: Origin[mut=True]](
            TileF32View[borrow_origin]
        ) raises thin -> None
    ](mut self) raises:
        var mfi = self.mfiter()
        while mfi.is_valid():
            tile_func(self.tile(mfi))
            mfi.next()

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
        value: Float32,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        if (
            multifab_plus(
                self.runtime[].lib,
                handle,
                Float64(value),
                start_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def mult(
        mut self,
        value: Float32,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        if (
            multifab_mult(
                self.runtime[].lib,
                handle,
                Float64(value),
                start_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def copy_from(
        mut self,
        ref source: MultiFabF32,
        src_comp: Int,
        dst_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        if (
            multifab_copy(
                self.runtime[].lib,
                handle,
                source._handle(),
                src_comp,
                dst_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def parallel_copy_from(
        mut self,
        ref source: MultiFabF32,
        ref geometry: Geometry,
        src_comp: Int,
        dst_comp: Int,
        ncomp: Int,
        src_ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
        dst_ngrow: IntVect3D = IntVect3D(x=0, y=0, z=0),
    ) raises:
        var handle = self._handle()
        if (
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
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def fill_boundary(
        mut self,
        ref geometry: Geometry,
        start_comp: Int,
        ncomp: Int,
        cross: Bool = False,
    ) raises:
        var handle = self._handle()
        if (
            multifab_fill_boundary(
                self.runtime[].lib,
                handle,
                geometry._handle(),
                start_comp,
                ncomp,
                cross,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    def fill_boundary(
        mut self, ref geometry: Geometry, cross: Bool = False
    ) raises:
        self.fill_boundary(geometry, 0, self.ncomp(), cross)

    def write_single_level_plotfile(
        ref self,
        plotfile: String,
        ref geometry: Geometry,
        time: Float64 = 0.0,
        level_step: Int = 0,
    ) raises:
        var handle = self._handle()
        if (
            multifab_write_single_level_plotfile(
                self.runtime[].lib,
                handle,
                geometry._handle(),
                plotfile,
                time,
                level_step,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

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

    def _handle(ref self) raises -> MultiFabHandle:
        require_live_handle(
            self.handle,
            (
                "MultiFabF32 no longer owns a live AMReX handle. The value may"
                " have been moved from."
            ),
        )
        return self.handle
