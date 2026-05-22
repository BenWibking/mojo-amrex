"""Helpers for staging host-backed AMReX views into Mojo device buffers.

These helpers support Mojo device kernels in user code. They do not expose an
AMReX-managed GPU runtime or direct AMReX device allocations.
"""

from amrex.ffi import Array4View, Box3D, TileView
from std.gpu.host import DeviceBuffer, DeviceContext


def array4_storage_size[
    dtype: DType,
    origin: Origin[mut=True],
](array: Array4View[dtype, origin]) -> Int:
    return array.storage_size()


struct StagedArray4[dtype: DType](Movable):
    var buffer: DeviceBuffer[Self.dtype]
    var device_view_: Array4View[Self.dtype, MutAnyOrigin]

    def __init__[
        origin: Origin[mut=True]
    ](out self, ref ctx: DeviceContext, array: Array4View[Self.dtype, origin],) raises:
        self.buffer = ctx.enqueue_create_buffer[Self.dtype](array4_storage_size(array))
        self.device_view_ = Array4View[Self.dtype, MutAnyOrigin](
            data=self.buffer.unsafe_ptr(),
            lo_x=array.lo_x,
            lo_y=array.lo_y,
            lo_z=array.lo_z,
            hi_x=array.hi_x,
            hi_y=array.hi_y,
            hi_z=array.hi_z,
            stride_i=array.stride_i,
            stride_j=array.stride_j,
            stride_k=array.stride_k,
            stride_n=array.stride_n,
            ncomp=array.ncomp,
        )

    def device_view(self) -> Array4View[Self.dtype, MutAnyOrigin]:
        return self.device_view_.copy()

    def load_from_host[
        origin: Origin[mut=True]
    ](mut self, ref ctx: DeviceContext, array: Array4View[Self.dtype, origin],) raises:
        ctx.enqueue_copy[Self.dtype](self.buffer, array.data)

    def store_to_host[
        origin: Origin[mut=True]
    ](mut self, ref ctx: DeviceContext, array: Array4View[Self.dtype, origin],) raises:
        ctx.enqueue_copy[Self.dtype](array.data, self.buffer)


struct StagedTile[dtype: DType](Movable):
    var tile_box: Box3D
    var array_stage: StagedArray4[Self.dtype]

    def __init__[origin: Origin[mut=True]](out self, ref ctx: DeviceContext, tile: TileView[Self.dtype, origin]) raises:
        var array = tile.array()
        self.tile_box = tile.tile_box.copy()
        self.array_stage = StagedArray4[Self.dtype](ctx, array)
        self.array_stage.load_from_host(ctx, array)

    def cell_count(self) -> Int:
        return (
            (Int(self.tile_box.big_end.x) - Int(self.tile_box.small_end.x) + 1)
            * (Int(self.tile_box.big_end.y) - Int(self.tile_box.small_end.y) + 1)
            * (Int(self.tile_box.big_end.z) - Int(self.tile_box.small_end.z) + 1)
        )

    def device_view(self) -> Array4View[Self.dtype, MutAnyOrigin]:
        return self.array_stage.device_view()

    def store_to_host[
        origin: Origin[mut=True]
    ](mut self, ref ctx: DeviceContext, tile: TileView[Self.dtype, origin]) raises:
        self.array_stage.store_to_host(ctx, tile.array())
