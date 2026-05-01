"""`Geometry` wrapper for the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    GeometryHandle,
    IntVect3D,
    OptionalGeometryHandle,
    RealBox3D,
    RealVect3D,
    geometry_cell_size,
    geometry_create,
    geometry_domain,
    geometry_periodicity,
    geometry_prob_domain,
    last_error_message,
)
from amrex.ownership import require_live_handle
from amrex.runtime import AmrexRuntime, RuntimeLease


struct Geometry(Movable):
    var runtime: RuntimeLease
    var handle: OptionalGeometryHandle

    def __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        self.runtime = runtime._lease()
        self.handle = geometry_create(
            self.runtime[].lib, self.runtime[].handle, domain
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __init__(
        out self,
        ref runtime: AmrexRuntime,
        domain: Box3D,
        real_box: RealBox3D,
        is_periodic: IntVect3D,
    ) raises:
        self.runtime = runtime._lease()
        self.handle = geometry_create(
            self.runtime[].lib,
            self.runtime[].handle,
            domain,
            real_box,
            is_periodic,
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __del__(deinit self):
        if self.handle:
            self.runtime[].lib.call["amrex_mojo_geometry_destroy"](
                self.handle.value()
            )

    def domain(ref self) raises -> Box3D:
        var handle = self._handle()
        return geometry_domain(self.runtime[].lib, handle)

    def prob_domain(ref self) raises -> RealBox3D:
        var handle = self._handle()
        return geometry_prob_domain(self.runtime[].lib, handle)

    def cell_size(ref self) raises -> RealVect3D:
        var handle = self._handle()
        return geometry_cell_size(self.runtime[].lib, handle)

    def periodicity(ref self) raises -> IntVect3D:
        var handle = self._handle()
        return geometry_periodicity(self.runtime[].lib, handle)

    def _handle(ref self) raises -> GeometryHandle:
        return require_live_handle(
            self.handle,
            (
                "Geometry no longer owns a live AMReX handle. The value may"
                " have been moved from."
            ),
        )
