"""`MFIter` wrapper for tile iteration in the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    IntVect3D,
    MFIterHandle,
    MultiFabHandle,
    gpu_num_streams,
    gpu_reset_stream,
    gpu_set_stream_index,
    gpu_stream,
    gpu_stream_synchronize_active,
    intvect3d,
    last_error_message,
    mfiter_create,
    mfiter_fab_box,
    mfiter_index,
    mfiter_is_valid,
    mfiter_local_tile_index,
    mfiter_next,
    mfiter_tile_box,
    mfiter_valid_box,
)
from amrex.ownership import require_live_handle
from amrex.runtime import RuntimeLease, require_matching_gpu_context
from std.ffi import c_int
from std.gpu.host import DeviceContext, DeviceStream


struct MFIter(Movable):
    var runtime: RuntimeLease
    var handle: MFIterHandle
    var default_ngrow: IntVect3D

    def __init__(
        out self,
        runtime: RuntimeLease,
        handle: MFIterHandle,
        default_ngrow: IntVect3D,
    ) raises:
        self.runtime = runtime
        self.handle = handle
        self.default_ngrow = default_ngrow.copy()

    def __del__(deinit self):
        if self.handle:
            self.runtime[].lib.call["amrex_mojo_mfiter_destroy"](self.handle)

    def is_valid(ref self) raises -> Bool:
        var handle = self._handle()
        return mfiter_is_valid(self.runtime[].lib, handle)

    def next(mut self) raises:
        var handle = self._handle()
        if mfiter_next(self.runtime[].lib, handle) != 0:
            raise Error(last_error_message(self.runtime[].lib))

    def index(ref self) raises -> Int:
        self._require_valid()
        return mfiter_index(self.runtime[].lib, self.handle)

    def local_tile_index(ref self) raises -> Int:
        self._require_valid()
        return mfiter_local_tile_index(self.runtime[].lib, self.handle)

    def tilebox(ref self) raises -> Box3D:
        self._require_valid()
        var handle = self._handle()
        var result = mfiter_tile_box(self.runtime[].lib, handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    def validbox(ref self) raises -> Box3D:
        self._require_valid()
        var handle = self._handle()
        var result = mfiter_valid_box(self.runtime[].lib, handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    def fabbox(ref self) raises -> Box3D:
        self._require_valid()
        var handle = self._handle()
        var result = mfiter_fab_box(self.runtime[].lib, handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    def growntilebox(ref self, ngrow: IntVect3D) raises -> Box3D:
        return self._growntilebox_impl(ngrow)

    def growntilebox(ref self, ngrow: Int) raises -> Box3D:
        return self._growntilebox_impl(intvect3d(ngrow, ngrow, ngrow))

    def growntilebox(ref self) raises -> Box3D:
        return self._growntilebox_impl(self.default_ngrow.copy())

    def _growntilebox_impl(ref self, ngrow: IntVect3D) raises -> Box3D:
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
        return box

    def _require_valid(ref self) raises:
        if not self.is_valid():
            raise Error("MFIter is not positioned on a valid tile.")

    def _handle(ref self) raises -> MFIterHandle:
        require_live_handle(
            self.handle,
            (
                "MFIter no longer owns a live AMReX handle. The value may have"
                " been moved from."
            ),
        )
        return self.handle


struct GpuMFIter(Movable):
    var runtime: RuntimeLease
    var mfiter: MFIter
    var num_streams: Int
    var tile_ordinal: Int
    var finalized: Bool

    def __init__(out self, var mfiter: MFIter) raises:
        self.runtime = mfiter.runtime
        self.mfiter = mfiter^
        self.num_streams = gpu_num_streams(self.runtime[].lib)
        self.tile_ordinal = 0
        self.finalized = False
        if self.mfiter.is_valid():
            self._activate_current_stream()

    def __del__(deinit self):
        if self.finalized:
            return
        _ = self.runtime[].lib.call[
            "amrex_mojo_gpu_stream_synchronize_active",
            c_int,
        ]()
        self.runtime[].lib.call["amrex_mojo_gpu_reset_stream"]()

    def is_valid(ref self) raises -> Bool:
        return self.mfiter.is_valid()

    def next(mut self) raises:
        self.mfiter.next()
        self.tile_ordinal += 1
        if self.mfiter.is_valid():
            self._activate_current_stream()
        else:
            self._finalize()

    def index(ref self) raises -> Int:
        return self.mfiter.index()

    def local_tile_index(ref self) raises -> Int:
        return self.mfiter.local_tile_index()

    def tilebox(ref self) raises -> Box3D:
        return self.mfiter.tilebox()

    def validbox(ref self) raises -> Box3D:
        return self.mfiter.validbox()

    def fabbox(ref self) raises -> Box3D:
        return self.mfiter.fabbox()

    def growntilebox(ref self, ngrow: IntVect3D) raises -> Box3D:
        return self.mfiter.growntilebox(ngrow)

    def growntilebox(ref self, ngrow: Int) raises -> Box3D:
        return self.mfiter.growntilebox(ngrow)

    def growntilebox(ref self) raises -> Box3D:
        return self.mfiter.growntilebox()

    def stream_index(ref self) raises -> Int:
        self._require_valid()
        return self.tile_ordinal % self.num_streams

    def stream_handle(
        ref self,
    ) raises -> UnsafePointer[NoneType, MutExternalOrigin]:
        self._require_valid()
        var handle = gpu_stream(self.runtime[].lib)
        if not handle:
            raise Error(last_error_message(self.runtime[].lib))
        return handle

    def stream(ref self, ref ctx: DeviceContext) raises -> DeviceStream:
        _ = require_matching_gpu_context(self.runtime, ctx)
        return ctx.create_external_stream(self.stream_handle())

    def synchronize(mut self) raises:
        self._finalize()

    def _handle(ref self) raises -> MFIterHandle:
        return self.mfiter._handle()

    def _activate_current_stream(mut self) raises:
        if gpu_set_stream_index(self.runtime[].lib, self.stream_index()) != 0:
            raise Error(last_error_message(self.runtime[].lib))

    def _finalize(mut self) raises:
        if self.finalized:
            return
        if gpu_stream_synchronize_active(self.runtime[].lib) != 0:
            raise Error(last_error_message(self.runtime[].lib))
        gpu_reset_stream(self.runtime[].lib)
        self.finalized = True

    def _require_valid(ref self) raises:
        if not self.is_valid():
            raise Error("GpuMFIter is not positioned on a valid tile.")


def create_mfiter(
    runtime: RuntimeLease,
    multifab: MultiFabHandle,
    default_ngrow: IntVect3D,
) raises -> MFIter:
    var handle = mfiter_create(runtime[].lib, multifab)
    if not handle:
        raise Error(last_error_message(runtime[].lib))
    return MFIter(runtime, handle, default_ngrow)


def create_gpu_mfiter(
    runtime: RuntimeLease,
    multifab: MultiFabHandle,
    default_ngrow: IntVect3D,
) raises -> GpuMFIter:
    return GpuMFIter(create_mfiter(runtime, multifab, default_ngrow))
