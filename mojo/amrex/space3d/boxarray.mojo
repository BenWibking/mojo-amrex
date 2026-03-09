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
from amrex.runtime import AmrexRuntime, RuntimeLease


struct BoxArray(Movable):
    var runtime: RuntimeLease
    var handle: BoxArrayHandle

    fn __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        self.runtime = runtime._lease()
        self.handle = boxarray_create_from_box(
            self.runtime[].lib, self.runtime[].handle, domain
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    fn __del__(deinit self):
        if self.handle:
            boxarray_destroy(self.runtime[].lib, self.handle)

    fn max_size(mut self, max_size: IntVect3D) raises:
        if boxarray_max_size(self.runtime[].lib, self.handle, max_size) != 0:
            raise Error(last_error_message(self.runtime[].lib))

    fn max_size(mut self, max_size: Int) raises:
        self.max_size(intvect3d(max_size, max_size, max_size))

    fn size(ref self) -> Int:
        return boxarray_size(self.runtime[].lib, self.handle)

    fn box(ref self, index: Int) raises -> Box3D:
        var result = boxarray_box(self.runtime[].lib, self.handle, index)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    fn _handle(ref self) -> BoxArrayHandle:
        return self.handle


struct DistributionMapping(Movable):
    var runtime: RuntimeLease
    var handle: DistributionMappingHandle

    fn __init__(
        out self, ref runtime: AmrexRuntime, ref boxarray: BoxArray
    ) raises:
        self.runtime = runtime._lease()
        self.handle = distmap_create_from_boxarray(
            self.runtime[].lib, self.runtime[].handle, boxarray._handle()
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    fn __del__(deinit self):
        if self.handle:
            distmap_destroy(self.runtime[].lib, self.handle)

    fn _handle(ref self) -> DistributionMappingHandle:
        return self.handle
