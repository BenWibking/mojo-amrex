"""`BoxArray` wrapper for the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    BoxArrayHandle,
    DistributionMappingHandle,
    IntVect3D,
    boxarray_box,
    boxarray_create_from_box,
    boxarray_destroy,
    boxarray_max_size,
    boxarray_size,
    distmap_create_from_boxarray,
    distmap_destroy,
    intvect3d,
    last_error_message,
)
from amrex.ownership import require_live_handle
from amrex.runtime import AmrexRuntime, RuntimeLease


struct BoxArray(Movable):
    var runtime: RuntimeLease
    var handle: BoxArrayHandle

    def __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        self.runtime = runtime._lease()
        self.handle = boxarray_create_from_box(
            self.runtime[].functions, self.runtime[].handle, domain
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].functions))

    def __del__(deinit self):
        if self.handle:
            self.runtime[].functions.boxarray_destroy_fn(self.handle)

    def max_size(mut self, max_size: IntVect3D) raises:
        var handle = self._handle()
        if boxarray_max_size(self.runtime[].functions, handle, max_size) != 0:
            raise Error(last_error_message(self.runtime[].functions))

    def max_size(mut self, max_size: Int) raises:
        self.max_size(intvect3d(max_size, max_size, max_size))

    def size(ref self) raises -> Int:
        var handle = self._handle()
        return boxarray_size(self.runtime[].functions, handle)

    def box(ref self, index: Int) raises -> Box3D:
        var handle = self._handle()
        var result = boxarray_box(self.runtime[].lib, handle, index)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    def _handle(ref self) raises -> BoxArrayHandle:
        require_live_handle(
            self.handle,
            (
                "BoxArray no longer owns a live AMReX handle. The value may"
                " have been moved from."
            ),
        )
        return self.handle


struct DistributionMapping(Movable):
    var runtime: RuntimeLease
    var handle: DistributionMappingHandle

    def __init__(
        out self, ref runtime: AmrexRuntime, ref boxarray: BoxArray
    ) raises:
        self.runtime = runtime._lease()
        self.handle = distmap_create_from_boxarray(
            self.runtime[].functions, self.runtime[].handle, boxarray._handle()
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].functions))

    def __del__(deinit self):
        if self.handle:
            self.runtime[].functions.distmap_destroy_fn(self.handle)

    def _handle(ref self) raises -> DistributionMappingHandle:
        require_live_handle(
            self.handle,
            (
                "DistributionMapping no longer owns a live AMReX handle. The"
                " value may have been moved from."
            ),
        )
        return self.handle
