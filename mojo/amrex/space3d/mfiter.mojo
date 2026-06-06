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
    mfiter_tile_box,
    mfiter_valid_box,
    raise_on_error,
)
from amrex.ownership import AmrexHandle, AmrexRawHandle, destroy_amrex_optional_handle
from amrex.runtime import RuntimeLease, require_matching_gpu_context
from amrex.space3d.parallelfor import AMREX_MOJO_CAN_COMPILE_GPU_PARALLEL_FOR, ParallelFor, ParallelForCpu
from std.builtin.device_passable import DevicePassable
from std.ffi import c_int
from std.gpu.host import DeviceContext, DeviceStream
from std.sys import has_accelerator


@fieldwise_init
struct MFIterTile(Copyable, Movable):
    var index: Int
    var local_tile_index: Int
    var tile_box: Box3D
    var valid_box: Box3D
    var fab_box: Box3D


@fieldwise_init
struct MFIterRange(Movable):
    var iter: MFIter

    def __iter__(deinit self) -> MFIter:
        return self.iter^


@fieldwise_init
struct MFIterIterator[origin: Origin[mut=True]](Iterator):
    comptime Element = MFIterTile

    var iter: UnsafePointer[MFIter, MutAnyOrigin]

    def __next__(mut self) raises StopIteration -> Self.Element:
        return self.iter[].__next__()


def _box_from_raw_parts(
    small_end: InlineArray[c_int, 3],
    big_end: InlineArray[c_int, 3],
    nodal: InlineArray[c_int, 3],
) -> Box3D:
    return Box3D(
        small_end=IntVect3D(x=small_end[0], y=small_end[1], z=small_end[2]),
        big_end=IntVect3D(x=big_end[0], y=big_end[1], z=big_end[2]),
        nodal=IntVect3D(x=nodal[0], y=nodal[1], z=nodal[2]),
    )


struct MFIter(AmrexHandle, Iterator, Movable):
    comptime Element = MFIterTile
    comptime moved_from_message = "MFIter no longer owns a live AMReX handle. The value may have been moved from."
    comptime destroy_symbol = "amrex_mojo_mfiter_destroy"
    var runtime: RuntimeLease
    var handle: OptionalMFIterHandle
    var default_ngrow: IntVect3D
    var gpu_backend_code: Int
    var num_streams: Int
    var tile_ordinal: Int
    var started: Bool
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
        self.started = False
        self.finalized = False
        self.ctx = None
        self.stream_wrapper = None
        if self._has_gpu_backend():
            if not has_accelerator():
                raise Error("AMReX has a GPU backend, but Mojo did not find a supported accelerator.")
            self.ctx = Optional[DeviceContext](DeviceContext())
            _ = require_matching_gpu_context(self.runtime, self.ctx.value())
            if self._is_valid():
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
        destroy_amrex_optional_handle[Self.destroy_symbol](self.runtime[].lib, self.handle)

    def _optional_handle(ref self) -> Optional[AmrexRawHandle]:
        return self.handle

    def _is_valid(ref self) raises -> Bool:
        var handle = self._handle()
        return mfiter_is_valid(self.runtime[].lib, handle)

    def __next__(mut self) raises StopIteration -> Self.Element:
        if not self.handle:
            raise StopIteration()
        var raw_handle = self.handle.value()

        if self.started:
            var next_status = self.runtime[].lib.call["amrex_mojo_mfiter_next", c_int](raw_handle)
            if next_status != 0:
                self._finalize_no_error()
                raise StopIteration()
            self.tile_ordinal += 1
            if self._has_gpu_backend():
                if self.runtime[].lib.call["amrex_mojo_mfiter_is_valid", c_int](raw_handle) != 0:
                    _ = self.runtime[].lib.call[
                        "amrex_mojo_gpu_set_stream_index",
                        c_int,
                        c_int,
                    ](c_int(self.tile_ordinal % self.num_streams))
                else:
                    self._finalize_no_error()
        else:
            self.started = True

        if self.runtime[].lib.call["amrex_mojo_mfiter_is_valid", c_int](raw_handle) == 0:
            self._finalize_no_error()
            raise StopIteration()

        var tile_small_end = InlineArray[c_int, 3](fill=0)
        var tile_big_end = InlineArray[c_int, 3](fill=0)
        var tile_nodal = InlineArray[c_int, 3](fill=0)
        var valid_small_end = InlineArray[c_int, 3](fill=0)
        var valid_big_end = InlineArray[c_int, 3](fill=0)
        var valid_nodal = InlineArray[c_int, 3](fill=0)
        var fab_small_end = InlineArray[c_int, 3](fill=0)
        var fab_big_end = InlineArray[c_int, 3](fill=0)
        var fab_nodal = InlineArray[c_int, 3](fill=0)

        var tile_status = self.runtime[].lib.call["amrex_mojo_mfiter_tile_box_metadata", c_int](
            raw_handle,
            tile_small_end.unsafe_ptr(),
            tile_big_end.unsafe_ptr(),
            tile_nodal.unsafe_ptr(),
        )
        var valid_status = self.runtime[].lib.call["amrex_mojo_mfiter_valid_box_metadata", c_int](
            raw_handle,
            valid_small_end.unsafe_ptr(),
            valid_big_end.unsafe_ptr(),
            valid_nodal.unsafe_ptr(),
        )
        var fab_status = self.runtime[].lib.call["amrex_mojo_mfiter_fab_box_metadata", c_int](
            raw_handle,
            fab_small_end.unsafe_ptr(),
            fab_big_end.unsafe_ptr(),
            fab_nodal.unsafe_ptr(),
        )
        if tile_status != 0 or valid_status != 0 or fab_status != 0:
            self._finalize_no_error()
            raise StopIteration()

        var tile = MFIterTile(
            index=Int(self.runtime[].lib.call["amrex_mojo_mfiter_index", c_int](raw_handle)),
            local_tile_index=Int(self.runtime[].lib.call["amrex_mojo_mfiter_local_tile_index", c_int](raw_handle)),
            tile_box=_box_from_raw_parts(tile_small_end, tile_big_end, tile_nodal),
            valid_box=_box_from_raw_parts(valid_small_end, valid_big_end, valid_nodal),
            fab_box=_box_from_raw_parts(fab_small_end, fab_big_end, fab_nodal),
        )
        return tile^

    def __iter__(mut self) -> MFIterIterator[origin_of(self)]:
        return MFIterIterator[origin_of(self)](UnsafePointer[MFIter, MutAnyOrigin](to=self))

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
        raise_on_error(self.runtime[].lib, result.status)
        return result.value.copy()

    def validbox(ref self) raises -> Box3D:
        self._require_valid()
        var handle = self._handle()
        var result = mfiter_valid_box(self.runtime[].lib, handle)
        raise_on_error(self.runtime[].lib, result.status)
        return result.value.copy()

    def fabbox(ref self) raises -> Box3D:
        self._require_valid()
        var handle = self._handle()
        var result = mfiter_fab_box(self.runtime[].lib, handle)
        raise_on_error(self.runtime[].lib, result.status)
        return result.value.copy()

    def growntilebox(ref self, ngrow: IntVect3D) raises -> Box3D:
        return self._growntilebox_impl(ngrow)

    def growntilebox(ref self, ngrow: Int) raises -> Box3D:
        return self._growntilebox_impl(intvect3d(ngrow, ngrow, ngrow))

    def growntilebox(ref self) raises -> Box3D:
        return self._growntilebox_impl(self.default_ngrow.copy())

    def parallel_for[
        body_type: (def(Int, Int, Int) -> None) & DevicePassable & ImplicitlyCopyable
    ](mut self, body: body_type, box: Box3D) raises:
        comptime if not AMREX_MOJO_CAN_COMPILE_GPU_PARALLEL_FOR:
            ParallelForCpu(body, box)
            return

        if not self._has_gpu_backend():
            ParallelForCpu(body, box)
            return
        self._activate_current_stream()
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
        if not self._is_valid():
            raise Error("MFIter is not positioned on a valid tile.")

    def _activate_current_stream(mut self) raises:
        raise_on_error(self.runtime[].lib, gpu_set_stream_index(self.runtime[].lib, self.stream_index()))

    def _refresh_stream_wrapper(mut self) raises:
        self.stream_wrapper = Optional[DeviceStream](self.ctx.value().create_external_stream(self.stream_handle()))

    def _finalize(mut self) raises:
        if self.finalized:
            return
        # Tile kernels are round-robined over AMReX streams, so fence every
        # stream before later AMReX operations consume the tile results.
        for stream_index in range(self.num_streams):
            raise_on_error(self.runtime[].lib, gpu_set_stream_index(self.runtime[].lib, stream_index))
            raise_on_error(self.runtime[].lib, gpu_stream_synchronize_active(self.runtime[].lib))
        gpu_reset_stream(self.runtime[].lib)
        self.finalized = True

    def _finalize_no_error(mut self):
        if self.finalized or not self._has_gpu_backend():
            return
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


def create_mfiter_range(
    runtime: RuntimeLease,
    multifab: MultiFabHandle,
    default_ngrow: IntVect3D,
    use_gpu_parallel: Bool,
) raises -> MFIterRange:
    return MFIterRange(iter=create_mfiter(runtime, multifab, default_ngrow, use_gpu_parallel))


def create_gpu_mfiter(
    runtime: RuntimeLease,
    multifab: MultiFabHandle,
    default_ngrow: IntVect3D,
    use_gpu_parallel: Bool,
) raises -> MFIter:
    return create_mfiter(runtime, multifab, default_ngrow, use_gpu_parallel)
