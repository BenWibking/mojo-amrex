"""`MultiFab` and `Array4` wrappers for the 3D binding layer."""

from amrex.ffi import (
    Array4F64View,
    IntVect3D,
    MultiFabHandle,
    TileF64View,
    array4_view_from_mfiter,
    last_error_message,
    multifab_copy,
    multifab_create,
    multifab_destroy,
    multifab_max,
    multifab_min,
    multifab_mult,
    multifab_ncomp,
    multifab_norm0,
    multifab_norm1,
    multifab_norm2,
    multifab_plus,
    multifab_set_val,
    multifab_sum,
    multifab_tile_count,
    multifab_write_single_level_plotfile,
    tile_view,
    zero_intvect3d,
)
from amrex.runtime import AmrexRuntime, RuntimeLease
from amrex.space3d.boxarray import BoxArray, DistributionMapping
from amrex.space3d.geometry import Geometry
from amrex.space3d.mfiter import MFIter, create_mfiter


struct MultiFab(Movable):
    var runtime: RuntimeLease
    var handle: MultiFabHandle
    var ngrow_vect: IntVect3D

    fn __init__(
        out self,
        ref runtime: AmrexRuntime,
        ref boxarray: BoxArray,
        ref distmap: DistributionMapping,
        ncomp: Int,
        ngrow: IntVect3D = zero_intvect3d(),
    ) raises:
        self.runtime = runtime._lease()
        self.handle = multifab_create(
            self.runtime[].lib,
            self.runtime[].handle,
            boxarray._handle(),
            distmap._handle(),
            ncomp,
            ngrow,
        )
        self.ngrow_vect = ngrow.copy()
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    fn __del__(deinit self):
        if self.handle:
            multifab_destroy(self.runtime[].lib, self.handle)

    fn ncomp(ref self) -> Int:
        return multifab_ncomp(self.runtime[].lib, self.handle)

    fn ngrow(ref self) -> IntVect3D:
        return self.ngrow_vect.copy()

    fn set_val(mut self, value: Float64, start_comp: Int, ncomp: Int) raises:
        if (
            multifab_set_val(
                self.runtime[].lib, self.handle, value, start_comp, ncomp
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    fn set_val(mut self, value: Float64) raises:
        self.set_val(value, 0, self.ncomp())

    fn tile_count(ref self) -> Int:
        return multifab_tile_count(self.runtime[].lib, self.handle)

    fn mfiter(ref self) raises -> MFIter:
        return create_mfiter(
            self.runtime,
            self.handle,
            self.ngrow_vect,
        )

    fn array[owner_origin: Origin[mut=True]](
        ref[owner_origin] self, tile_index: Int
    ) raises -> Array4F64View[owner_origin]:
        return self.tile(tile_index).array()

    fn array[owner_origin: Origin[mut=True]](
        ref[owner_origin] self, ref mfi: MFIter
    ) raises -> Array4F64View[owner_origin]:
        return self.tile(mfi).array()

    fn tile[owner_origin: Origin[mut=True]](
        ref[owner_origin] self, tile_index: Int
    ) raises -> TileF64View[owner_origin]:
        self._require_tile_index(tile_index)
        return tile_view[owner_origin](
            self.runtime[].lib, self.handle, tile_index
        )

    fn tile[owner_origin: Origin[mut=True]](
        ref[owner_origin] self, ref mfi: MFIter
    ) raises -> TileF64View[owner_origin]:
        var tile_box = mfi.tilebox()
        var valid_box = mfi.validbox()
        var array_view = array4_view_from_mfiter[owner_origin](
            self.runtime[].lib,
            self.handle,
            mfi._handle(),
        )
        if not array_view.data:
            raise Error(last_error_message(self.runtime[].lib))
        return TileF64View[owner_origin](
            tile_box=tile_box^,
            valid_box=valid_box^,
            array_view=array_view.copy(),
        )

    fn for_each_tile[
        tile_func: fn[borrow_origin: Origin[mut=True]](
            TileF64View[borrow_origin]
        ) raises -> None
    ](mut self) raises:
        for tile_index in range(self.tile_count()):
            tile_func(self.tile(tile_index))

    fn min(ref self, comp: Int) -> Float64:
        return multifab_min(self.runtime[].lib, self.handle, comp)

    fn max(ref self, comp: Int) -> Float64:
        return multifab_max(self.runtime[].lib, self.handle, comp)

    fn sum(ref self, comp: Int) -> Float64:
        return multifab_sum(self.runtime[].lib, self.handle, comp)

    fn norm0(ref self, comp: Int) -> Float64:
        return multifab_norm0(self.runtime[].lib, self.handle, comp)

    fn norm1(ref self, comp: Int) -> Float64:
        return multifab_norm1(self.runtime[].lib, self.handle, comp)

    fn norm2(ref self, comp: Int) -> Float64:
        return multifab_norm2(self.runtime[].lib, self.handle, comp)

    fn plus(
        mut self,
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = zero_intvect3d(),
    ) raises:
        if (
            multifab_plus(
                self.runtime[].lib,
                self.handle,
                value,
                start_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    fn mult(
        mut self,
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = zero_intvect3d(),
    ) raises:
        if (
            multifab_mult(
                self.runtime[].lib,
                self.handle,
                value,
                start_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    fn copy_from(
        mut self,
        ref source: MultiFab,
        src_comp: Int,
        dst_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = zero_intvect3d(),
    ) raises:
        if (
            multifab_copy(
                self.runtime[].lib,
                self.handle,
                source._handle(),
                src_comp,
                dst_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    fn write_single_level_plotfile(
        ref self,
        plotfile: String,
        ref geometry: Geometry,
        time: Float64 = 0.0,
        level_step: Int = 0,
    ) raises:
        if (
            multifab_write_single_level_plotfile(
                self.runtime[].lib,
                self.handle,
                geometry._handle(),
                plotfile,
                time,
                level_step,
            )
            != 0
        ):
            raise Error(last_error_message(self.runtime[].lib))

    fn write_single_level_plotfile(
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

    fn _require_tile_index(ref self, tile_index: Int) raises:
        if tile_index < 0 or tile_index >= self.tile_count():
            raise Error("tile index is out of range.")

    fn _handle(ref self) -> MultiFabHandle:
        return self.handle
