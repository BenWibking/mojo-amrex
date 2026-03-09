"""`Geometry` wrapper for the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    GeometryHandle,
    IntVect3D,
    RealBox3D,
    RealVect3D,
    geometry_cell_size,
    geometry_create,
    geometry_domain,
    geometry_destroy,
    geometry_periodicity,
    geometry_prob_domain,
    last_error_message,
)
from amrex.loader import load_library
from amrex.runtime import AmrexRuntime
from std.ffi import OwnedDLHandle


struct Geometry(Movable):
    var lib: OwnedDLHandle
    var handle: GeometryHandle

    fn __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        var path = runtime.library_path()
        self.lib = load_library(path)
        self.handle = geometry_create(self.lib, runtime._handle(), domain)
        if not self.handle:
            raise Error(last_error_message(self.lib))

    fn __del__(deinit self):
        if self.handle:
            geometry_destroy(self.lib, self.handle)

    fn domain(ref self) raises -> Box3D:
        var result = geometry_domain(self.lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.lib))
        return result.value.copy()

    fn prob_domain(ref self) raises -> RealBox3D:
        var result = geometry_prob_domain(self.lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.lib))
        return result.value.copy()

    fn cell_size(ref self) raises -> RealVect3D:
        var result = geometry_cell_size(self.lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.lib))
        return result.value.copy()

    fn periodicity(ref self) raises -> IntVect3D:
        var result = geometry_periodicity(self.lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.lib))
        return result.value.copy()

    fn _handle(ref self) -> GeometryHandle:
        return self.handle
