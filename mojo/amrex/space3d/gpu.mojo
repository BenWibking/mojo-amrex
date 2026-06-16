"""Helpers for staging host-backed AMReX views into Mojo device buffers.

These helpers support Mojo device kernels in user code. They do not expose an
AMReX-managed GPU runtime or direct AMReX device allocations.
"""

from amrex.ffi import Array4View, Box3D, TileView, box_cell_count
from amrex.floating_dtype import AmrexFloatingDtype
from std.gpu.host import DeviceBuffer, DeviceContext


def array4_storage_size[
    T: AmrexFloatingDtype,
    origin: Origin[mut=True],
](array: Array4View[T, origin]) -> Int:
    return array.storage_size()


struct StagedArray4[T: AmrexFloatingDtype](Movable):
    comptime dtype = Self.T.dtype

    var buffer: DeviceBuffer[Self.dtype]
    var device_view_: Array4View[Self.T, MutAnyOrigin]

    def __init__[
        origin: Origin[mut=True]
    ](out self, ref ctx: DeviceContext, array: Array4View[Self.T, origin],) raises:
        self.buffer = ctx.enqueue_create_buffer[Self.dtype](array4_storage_size(array))
        self.device_view_ = Array4View[Self.T, MutAnyOrigin](
            data=self.buffer.unsafe_ptr().as_unsafe_any_origin(),
            layout=array.layout_metadata(),
        )

    def device_view(self) -> Array4View[Self.T, MutAnyOrigin]:
        return self.device_view_.copy()

    def load_from_host[
        origin: Origin[mut=True]
    ](mut self, ref ctx: DeviceContext, array: Array4View[Self.T, origin],) raises:
        ctx.enqueue_copy[Self.dtype](self.buffer, array.data)

    def store_to_host[
        origin: Origin[mut=True]
    ](mut self, ref ctx: DeviceContext, array: Array4View[Self.T, origin],) raises:
        ctx.enqueue_copy[Self.dtype](array.data, self.buffer)


struct StagedTile[T: AmrexFloatingDtype](Movable):
    var tile_box: Box3D
    var array_stage: StagedArray4[Self.T]

    def __init__[origin: Origin[mut=True]](out self, ref ctx: DeviceContext, tile: TileView[Self.T, origin]) raises:
        var array = tile.array()
        self.tile_box = tile.tile_box.copy()
        self.array_stage = StagedArray4[Self.T](ctx, array)
        self.array_stage.load_from_host(ctx, array)

    def cell_count(self) -> Int:
        return box_cell_count(self.tile_box)

    def device_view(self) -> Array4View[Self.T, MutAnyOrigin]:
        return self.array_stage.device_view()

    def store_to_host[
        origin: Origin[mut=True]
    ](mut self, ref ctx: DeviceContext, tile: TileView[Self.T, origin]) raises:
        self.array_stage.store_to_host(ctx, tile.array())
