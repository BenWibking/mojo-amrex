"""`MFIter` wrapper for tile iteration in the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    GPU_BACKEND_NONE,
    IntVect3D,
    MFIterHandle,
    MultiFabHandle,
    OptionalMFIterHandle,
    gpu_backend,
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
from amrex.space3d.parallelfor import AMREX_MOJO_CAN_COMPILE_GPU_PARALLEL_FOR, ParallelFor, ParallelForCpu
from std.builtin.device_passable import DevicePassable
from std.ffi import c_int
from std.gpu.host import DeviceContext, DeviceStream
from std.sys import has_accelerator


struct MFIter(Movable):
    var runtime: RuntimeLease
    var handle: OptionalMFIterHandle
    var default_ngrow: IntVect3D
    var gpu_backend_code: Int
    var num_streams: Int
    var tile_ordinal: Int
    var finalized: Bool
    var ctx: Optional[DeviceContext]
    var stream_wrapper: Optional[DeviceStream]

    def __init__(
        out self,
        runtime: RuntimeLease,
        handle: MFIterHandle,
        default_ngrow: IntVect3D,
        use_gpu_parallel: Bool,
    ) raises:
        self.runtime = runtime
        self.handle = OptionalMFIterHandle(handle)
        self.default_ngrow = default_ngrow.copy()
        if use_gpu_parallel:
            self.gpu_backend_code = gpu_backend(self.runtime[].lib)
        else:
            self.gpu_backend_code = GPU_BACKEND_NONE
        self.num_streams = gpu_num_streams(self.runtime[].lib)
        self.tile_ordinal = 0
        self.finalized = False
        self.ctx = None
        self.stream_wrapper = None
        if self._has_gpu_backend():
            if not has_accelerator():
                raise Error("AMReX has a GPU backend, but Mojo did not find a supported accelerator.")
            self.ctx = Optional[DeviceContext](DeviceContext())
            _ = require_matching_gpu_context(self.runtime, self.ctx.value())
            if self.is_valid():
                self._activate_current_stream()
                self._refresh_stream_wrapper()

    def __del__(deinit self):
        if self._has_gpu_backend() and not self.finalized:
            for stream_index in range(self.num_streams):
                _ = self.runtime[].lib.call[
                    "amrex_mojo_gpu_set_stream_index",
                    c_int,
                    c_int,
                ](c_int(stream_index))
                _ = self.runtime[].lib.call[
                    "amrex_mojo_gpu_stream_synchronize_active",
                    c_int,
                ]()
            self.runtime[].lib.call["amrex_mojo_gpu_reset_stream"]()
        if self.handle:
            self.runtime[].lib.call["amrex_mojo_mfiter_destroy"](self.handle.value())

    def is_valid(ref self) raises -> Bool:
        var handle = self._handle()
        return mfiter_is_valid(self.runtime[].lib, handle)

    def next(mut self) raises:
        var handle = self._handle()
        if mfiter_next(self.runtime[].lib, handle) != 0:
            raise Error(last_error_message(self.runtime[].lib))
        self.tile_ordinal += 1
        if self._has_gpu_backend():
            if self.is_valid():
                self._activate_current_stream()
                self._refresh_stream_wrapper()
            else:
                self._finalize()

    def index(ref self) raises -> Int:
        self._require_valid()
        return mfiter_index(self.runtime[].lib, self._handle())

    def local_tile_index(ref self) raises -> Int:
        self._require_valid()
        return mfiter_local_tile_index(self.runtime[].lib, self._handle())

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

    def parallel_for[
        body_type: (def(Int, Int, Int) register_passable -> None) & DevicePassable
    ](mut self, body: body_type, box: Box3D) raises:
        comptime if not AMREX_MOJO_CAN_COMPILE_GPU_PARALLEL_FOR:
            ParallelForCpu(body, box)
            return

        if not self._has_gpu_backend():
            ParallelForCpu(body, box)
            return
        if not self.stream_wrapper:
            self._refresh_stream_wrapper()
        ParallelFor(self.ctx.value(), self.stream_wrapper.value(), body, box)

    def stream_index(ref self) raises -> Int:
        self._require_gpu_backend()
        self._require_valid()
        return self.tile_ordinal % self.num_streams

    def stream_handle(
        mut self,
    ) raises -> UnsafePointer[NoneType, MutExternalOrigin]:
        self._require_gpu_backend()
        self._require_valid()
        self._activate_current_stream()
        var handle = gpu_stream(self.runtime[].lib)
        if not handle:
            raise Error(last_error_message(self.runtime[].lib))
        return handle.value()

    def stream(mut self, ref ctx: DeviceContext) raises -> DeviceStream:
        _ = require_matching_gpu_context(self.runtime, ctx)
        return ctx.create_external_stream(self.stream_handle())

    def synchronize(mut self) raises:
        if self._has_gpu_backend():
            self._finalize()

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
        return require_live_handle(
            self.handle,
            "MFIter no longer owns a live AMReX handle. The value may have been moved from.",
        )

    def _activate_current_stream(mut self) raises:
        if gpu_set_stream_index(self.runtime[].lib, self.stream_index()) != 0:
            raise Error(last_error_message(self.runtime[].lib))

    def _refresh_stream_wrapper(mut self) raises:
        self.stream_wrapper = Optional[DeviceStream](self.ctx.value().create_external_stream(self.stream_handle()))

    def _finalize(mut self) raises:
        if self.finalized:
            return
        # Tile kernels are round-robined over AMReX streams, so fence every
        # stream before later AMReX operations consume the tile results.
        for stream_index in range(self.num_streams):
            if gpu_set_stream_index(self.runtime[].lib, stream_index) != 0:
                raise Error(last_error_message(self.runtime[].lib))
            if gpu_stream_synchronize_active(self.runtime[].lib) != 0:
                raise Error(last_error_message(self.runtime[].lib))
        gpu_reset_stream(self.runtime[].lib)
        self.finalized = True

    def _has_gpu_backend(ref self) -> Bool:
        return self.gpu_backend_code != GPU_BACKEND_NONE

    def _require_gpu_backend(ref self) raises:
        if not self._has_gpu_backend():
            raise Error("The loaded AMReX library was built without GPU support.")


def create_mfiter(
    runtime: RuntimeLease,
    multifab: MultiFabHandle,
    default_ngrow: IntVect3D,
    use_gpu_parallel: Bool,
) raises -> MFIter:
    var handle = mfiter_create(runtime[].lib, multifab)
    if not handle:
        raise Error(last_error_message(runtime[].lib))
    return MFIter(runtime, handle.value(), default_ngrow, use_gpu_parallel)


def create_gpu_mfiter(
    runtime: RuntimeLease,
    multifab: MultiFabHandle,
    default_ngrow: IntVect3D,
    use_gpu_parallel: Bool,
) raises -> MFIter:
    return create_mfiter(runtime, multifab, default_ngrow, use_gpu_parallel)
