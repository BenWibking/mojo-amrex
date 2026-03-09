"""`MultiFab` and `Array4` wrappers for the 3D binding layer."""

from amrex.ffi import (
    Array4F64View,
    IntVect3D,
    MultiFabHandle,
    TileF64View,
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
    tile_view,
    zero_intvect3d,
)
from amrex.loader import load_library
from amrex.runtime import AmrexRuntime
from amrex.space3d.boxarray import BoxArray, DistributionMapping
from std.ffi import OwnedDLHandle


struct MultiFab(Movable):
    var lib: OwnedDLHandle
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
        var path = runtime.library_path()
        self.lib = load_library(path)
        self.handle = multifab_create(
            self.lib,
            runtime._handle(),
            boxarray._handle(),
            distmap._handle(),
            ncomp,
            ngrow,
        )
        self.ngrow_vect = ngrow.copy()
        if not self.handle:
            raise Error(last_error_message(self.lib))

    fn __del__(deinit self):
        if self.handle:
            multifab_destroy(self.lib, self.handle)

    fn ncomp(ref self) -> Int:
        return multifab_ncomp(self.lib, self.handle)

    fn ngrow(ref self) -> IntVect3D:
        return self.ngrow_vect.copy()

    fn set_val(mut self, value: Float64, start_comp: Int, ncomp: Int) raises:
        if (
            multifab_set_val(self.lib, self.handle, value, start_comp, ncomp)
            != 0
        ):
            raise Error(last_error_message(self.lib))

    fn set_val(mut self, value: Float64) raises:
        self.set_val(value, 0, self.ncomp())

    fn tile_count(ref self) -> Int:
        return multifab_tile_count(self.lib, self.handle)

    fn array(ref self, tile_index: Int) raises -> Array4F64View:
        return self.tile(tile_index).array()

    fn tile(ref self, tile_index: Int) raises -> TileF64View:
        self._require_tile_index(tile_index)
        return tile_view(self.lib, self.handle, tile_index)

    fn min(ref self, comp: Int) -> Float64:
        return multifab_min(self.lib, self.handle, comp)

    fn max(ref self, comp: Int) -> Float64:
        return multifab_max(self.lib, self.handle, comp)

    fn sum(ref self, comp: Int) -> Float64:
        return multifab_sum(self.lib, self.handle, comp)

    fn norm0(ref self, comp: Int) -> Float64:
        return multifab_norm0(self.lib, self.handle, comp)

    fn norm1(ref self, comp: Int) -> Float64:
        return multifab_norm1(self.lib, self.handle, comp)

    fn norm2(ref self, comp: Int) -> Float64:
        return multifab_norm2(self.lib, self.handle, comp)

    fn plus(
        mut self,
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = zero_intvect3d(),
    ) raises:
        if (
            multifab_plus(
                self.lib, self.handle, value, start_comp, ncomp, ngrow
            )
            != 0
        ):
            raise Error(last_error_message(self.lib))

    fn mult(
        mut self,
        value: Float64,
        start_comp: Int,
        ncomp: Int,
        ngrow: IntVect3D = zero_intvect3d(),
    ) raises:
        if (
            multifab_mult(
                self.lib, self.handle, value, start_comp, ncomp, ngrow
            )
            != 0
        ):
            raise Error(last_error_message(self.lib))

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
                self.lib,
                self.handle,
                source._handle(),
                src_comp,
                dst_comp,
                ncomp,
                ngrow,
            )
            != 0
        ):
            raise Error(last_error_message(self.lib))

    fn _require_tile_index(ref self, tile_index: Int) raises:
        if tile_index < 0 or tile_index >= self.tile_count():
            raise Error("tile index is out of range.")

    fn _handle(ref self) -> MultiFabHandle:
        return self.handle
