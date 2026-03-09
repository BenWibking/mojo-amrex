"""`MFIter` wrapper for tile iteration in the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    IntVect3D,
    MFIterHandle,
    MultiFabHandle,
    intvect3d,
    last_error_message,
    mfiter_create,
    mfiter_destroy,
    mfiter_fab_box,
    mfiter_index,
    mfiter_is_valid,
    mfiter_local_tile_index,
    mfiter_next,
    mfiter_tile_box,
    mfiter_valid_box,
)
from amrex.runtime import RuntimeLease


struct MFIter(Movable):
    var runtime: RuntimeLease
    var handle: MFIterHandle
    var default_ngrow: IntVect3D

    fn __init__(
        out self,
        runtime: RuntimeLease,
        handle: MFIterHandle,
        default_ngrow: IntVect3D,
    ):
        self.runtime = runtime
        self.handle = handle
        self.default_ngrow = default_ngrow.copy()

    fn __del__(deinit self):
        if self.handle:
            mfiter_destroy(self.runtime[].lib, self.handle)

    fn is_valid(ref self) -> Bool:
        return mfiter_is_valid(self.runtime[].lib, self.handle)

    fn next(mut self) raises:
        if mfiter_next(self.runtime[].lib, self.handle) != 0:
            raise Error(last_error_message(self.runtime[].lib))

    fn index(ref self) raises -> Int:
        self._require_valid()
        return mfiter_index(self.runtime[].lib, self.handle)

    fn local_tile_index(ref self) raises -> Int:
        self._require_valid()
        return mfiter_local_tile_index(self.runtime[].lib, self.handle)

    fn tilebox(ref self) raises -> Box3D:
        self._require_valid()
        var result = mfiter_tile_box(self.runtime[].lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    fn validbox(ref self) raises -> Box3D:
        self._require_valid()
        var result = mfiter_valid_box(self.runtime[].lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    fn fabbox(ref self) raises -> Box3D:
        self._require_valid()
        var result = mfiter_fab_box(self.runtime[].lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    fn growntilebox(ref self, ngrow: IntVect3D) raises -> Box3D:
        return self._growntilebox_impl(ngrow)

    fn growntilebox(ref self, ngrow: Int) raises -> Box3D:
        return self._growntilebox_impl(intvect3d(ngrow, ngrow, ngrow))

    fn growntilebox(ref self) raises -> Box3D:
        return self._growntilebox_impl(self.default_ngrow.copy())

    fn _growntilebox_impl(ref self, ngrow: IntVect3D) raises -> Box3D:
        self._require_valid()
        var box = self.tilebox()
        var valid = self.validbox()
        if box.small_end.x == valid.small_end.x:
            box.small_end.x -= ngrow.x
        if box.small_end.y == valid.small_end.y:
            box.small_end.y -= ngrow.y
        if box.small_end.z == valid.small_end.z:
            box.small_end.z -= ngrow.z
        if box.big_end.x == valid.big_end.x:
            box.big_end.x += ngrow.x
        if box.big_end.y == valid.big_end.y:
            box.big_end.y += ngrow.y
        if box.big_end.z == valid.big_end.z:
            box.big_end.z += ngrow.z
        return box^

    fn _require_valid(ref self) raises:
        if not self.is_valid():
            raise Error("MFIter is not positioned on a valid tile.")

    fn _handle(ref self) -> MFIterHandle:
        return self.handle


fn create_mfiter(
    runtime: RuntimeLease,
    multifab: MultiFabHandle,
    default_ngrow: IntVect3D,
) raises -> MFIter:
    var handle = mfiter_create(runtime[].lib, multifab)
    if not handle:
        raise Error(last_error_message(runtime[].lib))
    return MFIter(runtime, handle, default_ngrow)
