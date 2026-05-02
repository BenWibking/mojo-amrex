"""`BoxArray` wrapper for the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    BoxArrayHandle,
    DistributionMappingHandle,
    IntVect3D,
    OptionalBoxArrayHandle,
    OptionalDistributionMappingHandle,
    boxarray_box,
    boxarray_create_from_box,
    boxarray_max_size,
    boxarray_size,
    distmap_create_from_boxarray,
    intvect3d,
    last_error_message,
)
from amrex.ownership import require_live_handle
from amrex.runtime import AmrexRuntime, RuntimeLease


struct BoxArray(Movable):
    var runtime: RuntimeLease
    var handle: OptionalBoxArrayHandle

    def __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        self.runtime = runtime._lease()
        self.handle = boxarray_create_from_box(self.runtime[].lib, self.runtime[].handle, domain)
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __del__(deinit self):
        if self.handle:
            self.runtime[].lib.call["amrex_mojo_boxarray_destroy"](self.handle.value())

    def max_size(mut self, max_size: IntVect3D) raises:
        var handle = self._handle()
        if boxarray_max_size(self.runtime[].lib, handle, max_size) != 0:
            raise Error(last_error_message(self.runtime[].lib))

    def max_size(mut self, max_size: Int) raises:
        self.max_size(intvect3d(max_size, max_size, max_size))

    def size(ref self) raises -> Int:
        var handle = self._handle()
        return boxarray_size(self.runtime[].lib, handle)

    def box(ref self, index: Int) raises -> Box3D:
        var handle = self._handle()
        if index < 0 or index >= self.size():
            raise Error("BoxArray box index is out of range.")
        return boxarray_box(self.runtime[].lib, handle, index)

    def _handle(ref self) raises -> BoxArrayHandle:
        return require_live_handle(
            self.handle,
            "BoxArray no longer owns a live AMReX handle. The value may have been moved from.",
        )


struct DistributionMapping(Movable):
    var runtime: RuntimeLease
    var handle: OptionalDistributionMappingHandle

    def __init__(out self, ref runtime: AmrexRuntime, ref boxarray: BoxArray) raises:
        self.runtime = runtime._lease()
        self.handle = distmap_create_from_boxarray(self.runtime[].lib, self.runtime[].handle, boxarray._handle())
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __del__(deinit self):
        if self.handle:
            self.runtime[].lib.call["amrex_mojo_distmap_destroy"](self.handle.value())

    def _handle(ref self) raises -> DistributionMappingHandle:
        return require_live_handle(
            self.handle,
            "DistributionMapping no longer owns a live AMReX handle. The value may have been moved from.",
        )
