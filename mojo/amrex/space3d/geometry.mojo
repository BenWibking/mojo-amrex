# ABOUTME: Geometry wrapper exposing AMReX domain and coordinate metadata.
# ABOUTME: Provides domain, prob_domain, cell_size, and periodicity queries.

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
from amrex.ownership import AmrexHandle, AmrexRawHandle, destroy_amrex_optional_handle
from amrex.runtime import AmrexRuntime, RuntimeLease


struct Geometry(AmrexHandle, Movable):
    comptime moved_from_message = "Geometry no longer owns a live AMReX handle. The value may have been moved from."
    comptime destroy_symbol = "amrex_mojo_geometry_destroy"
    var runtime: RuntimeLease
    var handle: OptionalGeometryHandle

    def __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        self.runtime = runtime._lease()
        self.handle = geometry_create(self.runtime[].lib, self.runtime[].handle, domain)
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
        destroy_amrex_optional_handle[Self.destroy_symbol](self.runtime[].lib, self.handle)

    def _optional_handle(ref self) -> Optional[AmrexRawHandle]:
        return self.handle

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
