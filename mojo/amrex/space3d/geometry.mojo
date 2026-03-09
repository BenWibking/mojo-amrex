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
from amrex.runtime import AmrexRuntime, RuntimeLease


struct Geometry(Movable):
    var runtime: RuntimeLease
    var handle: GeometryHandle

    fn __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        self.runtime = runtime._lease()
        self.handle = geometry_create(
            self.runtime[].lib, self.runtime[].handle, domain
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    fn __del__(deinit self):
        if self.handle:
            geometry_destroy(self.runtime[].lib, self.handle)

    fn domain(ref self) raises -> Box3D:
        var result = geometry_domain(self.runtime[].lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    fn prob_domain(ref self) raises -> RealBox3D:
        var result = geometry_prob_domain(self.runtime[].lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    fn cell_size(ref self) raises -> RealVect3D:
        var result = geometry_cell_size(self.runtime[].lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    fn periodicity(ref self) raises -> IntVect3D:
        var result = geometry_periodicity(self.runtime[].lib, self.handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    fn _handle(ref self) -> GeometryHandle:
        return self.handle
