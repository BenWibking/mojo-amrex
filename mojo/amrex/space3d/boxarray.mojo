"""`BoxArray` wrapper for the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    BoxArrayHandle,
    DistributionMappingHandle,
    IntVect3D,
    boxarray_create_from_box,
    boxarray_destroy,
    boxarray_max_size,
    boxarray_size,
    distmap_create_from_boxarray,
    distmap_destroy,
    intvect3d,
    last_error_message,
)
from amrex.loader import load_library
from amrex.runtime import AmrexRuntime
from std.ffi import OwnedDLHandle


struct BoxArray(Movable):
    var lib: OwnedDLHandle
    var handle: BoxArrayHandle

    fn __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        var path = runtime.library_path()
        self.lib = load_library(path)
        self.handle = boxarray_create_from_box(
            self.lib, runtime._handle(), domain
        )
        if not self.handle:
            raise Error(last_error_message(self.lib))

    fn __del__(deinit self):
        if self.handle:
            boxarray_destroy(self.lib, self.handle)

    fn max_size(mut self, max_size: IntVect3D) raises:
        if boxarray_max_size(self.lib, self.handle, max_size) != 0:
            raise Error(last_error_message(self.lib))

    fn max_size(mut self, max_size: Int) raises:
        self.max_size(intvect3d(max_size, max_size, max_size))

    fn size(ref self) -> Int:
        return boxarray_size(self.lib, self.handle)

    fn _handle(ref self) -> BoxArrayHandle:
        return self.handle


struct DistributionMapping(Movable):
    var lib: OwnedDLHandle
    var handle: DistributionMappingHandle

    fn __init__(
        out self, ref runtime: AmrexRuntime, ref boxarray: BoxArray
    ) raises:
        var path = runtime.library_path()
        self.lib = load_library(path)
        self.handle = distmap_create_from_boxarray(
            self.lib, runtime._handle(), boxarray._handle()
        )
        if not self.handle:
            raise Error(last_error_message(self.lib))

    fn __del__(deinit self):
        if self.handle:
            distmap_destroy(self.lib, self.handle)

    fn _handle(ref self) -> DistributionMappingHandle:
        return self.handle
