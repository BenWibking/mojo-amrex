"""`Geometry` wrapper for the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    GeometryHandle,
    IntVect3D,
    RealBox3D,
    RealVect3D,
    geometry_cell_size,
    geometry_create,
    geometry_destroy,
    geometry_domain,
    geometry_periodicity,
    geometry_prob_domain,
    last_error_message,
)
from amrex.ownership import require_live_handle
from amrex.runtime import AmrexRuntime, RuntimeLease


struct Geometry(Movable):
    var runtime: RuntimeLease
    var handle: GeometryHandle

    def __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        self.runtime = runtime._lease()
        self.handle = geometry_create(
            self.runtime[].functions, self.runtime[].handle, domain
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].functions))

    def __init__(
        out self,
        ref runtime: AmrexRuntime,
        domain: Box3D,
        real_box: RealBox3D,
        is_periodic: IntVect3D,
    ) raises:
        self.runtime = runtime._lease()
        self.handle = geometry_create(
            self.runtime[].functions,
            self.runtime[].handle,
            domain,
            real_box,
            is_periodic,
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].functions))

    def __del__(deinit self):
        if self.handle:
            self.runtime[].functions.geometry_destroy_fn(self.handle)

    def domain(ref self) raises -> Box3D:
        var handle = self._handle()
        var result = geometry_domain(self.runtime[].lib, handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    def prob_domain(ref self) raises -> RealBox3D:
        var handle = self._handle()
        var result = geometry_prob_domain(self.runtime[].lib, handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    def cell_size(ref self) raises -> RealVect3D:
        var handle = self._handle()
        var result = geometry_cell_size(self.runtime[].lib, handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    def periodicity(ref self) raises -> IntVect3D:
        var handle = self._handle()
        var result = geometry_periodicity(self.runtime[].lib, handle)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        return result.value.copy()

    def _handle(ref self) raises -> GeometryHandle:
        require_live_handle(
            self.handle,
            (
                "Geometry no longer owns a live AMReX handle. The value may"
                " have been moved from."
            ),
        )
        return self.handle
