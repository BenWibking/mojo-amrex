# ABOUTME: BoxArray and DistributionMapping wrappers for 3D domains.
# ABOUTME: Handles domain decomposition and mapping boxes to MPI ranks.

"""`BoxArray` wrapper for the 3D binding layer."""

from amrex.ffi import (
    Box3D,
    BoxArrayHandle,
    DistributionMappingHandle,
    IntVect3D,
    OptionalBoxArrayHandle,
    OptionalDistributionMappingHandle,
    boxarray_box,
    boxarray_convert,
    boxarray_convert_copy,
    boxarray_create_from_box,
    boxarray_max_size,
    boxarray_size,
    boxarray_surrounding_nodes,
    boxarray_surrounding_nodes_all,
    distmap_create_from_boxarray,
    intvect3d,
    last_error_message,
    raise_on_error,
)
from amrex.ownership import AmrexHandle, AmrexRawHandle, destroy_amrex_optional_handle
from amrex.runtime import AmrexRuntime, RuntimeLease


struct BoxArray(AmrexHandle, Movable):
    comptime moved_from_message = "BoxArray no longer owns a live AMReX handle. The value may have been moved from."
    comptime destroy_symbol = "amrex_mojo_boxarray_destroy"
    var runtime: RuntimeLease
    var handle: OptionalBoxArrayHandle

    def __init__(out self, ref runtime: AmrexRuntime, domain: Box3D) raises:
        self.runtime = runtime._lease()
        self.handle = boxarray_create_from_box(self.runtime[].lib, self.runtime[].handle, domain)
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __init__(out self, var runtime: RuntimeLease, handle: BoxArrayHandle):
        self.runtime = runtime^
        self.handle = OptionalBoxArrayHandle(handle)

    def __del__(deinit self):
        destroy_amrex_optional_handle[Self.destroy_symbol](self.runtime[].lib, self.handle)

    def _optional_handle(ref self) -> Optional[AmrexRawHandle]:
        return self.handle

    def max_size(mut self, max_size: IntVect3D) raises:
        var handle = self._handle()
        raise_on_error(self.runtime[].lib, boxarray_max_size(self.runtime[].lib, handle, max_size))

    def max_size(mut self, max_size: Int) raises:
        self.max_size(intvect3d(max_size, max_size, max_size))

    def surrounding_nodes(mut self, dir: Int) raises:
        var handle = self._handle()
        raise_on_error(
            self.runtime[].lib,
            boxarray_surrounding_nodes(self.runtime[].lib, handle, dir),
        )

    def surrounding_nodes(mut self) raises:
        var handle = self._handle()
        raise_on_error(
            self.runtime[].lib,
            boxarray_surrounding_nodes_all(self.runtime[].lib, handle),
        )

    def convert(mut self, typ: IntVect3D) raises:
        var handle = self._handle()
        raise_on_error(
            self.runtime[].lib,
            boxarray_convert(self.runtime[].lib, handle, typ),
        )

    def size(ref self) raises -> Int:
        var handle = self._handle()
        return boxarray_size(self.runtime[].lib, handle)

    def box(ref self, index: Int) raises -> Box3D:
        var handle = self._handle()
        if index < 0 or index >= self.size():
            raise Error("BoxArray box index is out of range.")
        return boxarray_box(self.runtime[].lib, handle, index)


def convert(ref boxarray: BoxArray, typ: IntVect3D) raises -> BoxArray:
    var handle = boxarray_convert_copy(
        boxarray.runtime[].lib,
        boxarray._handle(),
        typ,
    )
    if not handle:
        raise Error(last_error_message(boxarray.runtime[].lib))
    return BoxArray(boxarray.runtime.copy(), handle.value())


struct DistributionMapping(AmrexHandle, Movable):
    comptime moved_from_message = (
        "DistributionMapping no longer owns a live AMReX handle. The value may have been moved from."
    )
    comptime destroy_symbol = "amrex_mojo_distmap_destroy"
    var runtime: RuntimeLease
    var handle: OptionalDistributionMappingHandle

    def __init__(out self, ref runtime: AmrexRuntime, ref boxarray: BoxArray) raises:
        self.runtime = runtime._lease()
        self.handle = distmap_create_from_boxarray(self.runtime[].lib, self.runtime[].handle, boxarray._handle())
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __del__(deinit self):
        destroy_amrex_optional_handle[Self.destroy_symbol](self.runtime[].lib, self.handle)

    def _optional_handle(ref self) -> Optional[AmrexRawHandle]:
        return self.handle
