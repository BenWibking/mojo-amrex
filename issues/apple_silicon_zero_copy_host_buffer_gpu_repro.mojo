"""Standalone reproducer for incorrect Mojo GPU results with zero-copy host buffers.

This mirrors `examples/multifab_smoke_mojo_gpu.mojo`, but replaces the AMReX
bindings with simple `List`-backed host storage and stdlib staging helpers.
On affected Apple Silicon systems, the direct zero-copy path leaves the
destination buffer unchanged while the staged path produces the expected sum.
"""

from std.builtin.device_passable import DevicePassable
from std.collections import List
from std.ffi import c_float, c_int
from std.gpu import global_idx
from std.gpu.host import DeviceBuffer, DeviceContext
from std.math import ceildiv
from std.sys import has_accelerator


comptime DOMAIN_EXTENT = 64
comptime TILE_EXTENT = 32
comptime NGROW = 1
comptime KERNEL_BLOCK_SIZE = 256
comptime TILE_FILL_VALUE = 42


def init_device_passable_value[
    T: TrivialRegisterPassable,
    mut_origin: Origin[mut=True],
](value: T, target: UnsafePointer[NoneType, mut_origin]):
    target.bitcast[T]().init_pointee_copy(value)


@fieldwise_init
struct IntVect3D(TrivialRegisterPassable, DevicePassable):
    comptime device_type = Self

    var x: c_int
    var y: c_int
    var z: c_int

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](
        self,
        target: UnsafePointer[NoneType, mut_origin],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("IntVect3D")


@fieldwise_init
struct Box3D(TrivialRegisterPassable, DevicePassable):
    comptime device_type = Self

    var small_end: IntVect3D
    var big_end: IntVect3D
    var nodal: IntVect3D

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](
        self,
        target: UnsafePointer[NoneType, mut_origin],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("Box3D")


def intvect3d(x: Int, y: Int, z: Int) -> IntVect3D:
    return IntVect3D(x=c_int(x), y=c_int(y), z=c_int(z))


def box3d(
    small_end: IntVect3D,
    big_end: IntVect3D,
    nodal: IntVect3D = IntVect3D(x=0, y=0, z=0),
) -> Box3D:
    return Box3D(
        small_end=small_end.copy(),
        big_end=big_end.copy(),
        nodal=nodal.copy(),
    )


def grow_box(box: Box3D, ngrow: Int) -> Box3D:
    return box3d(
        small_end=intvect3d(
            Int(box.small_end.x) - ngrow,
            Int(box.small_end.y) - ngrow,
            Int(box.small_end.z) - ngrow,
        ),
        big_end=intvect3d(
            Int(box.big_end.x) + ngrow,
            Int(box.big_end.y) + ngrow,
            Int(box.big_end.z) + ngrow,
        ),
        nodal=box.nodal.copy(),
    )


def box_cell_count(box: Box3D) -> Int:
    return (
        (Int(box.big_end.x) - Int(box.small_end.x) + 1)
        * (Int(box.big_end.y) - Int(box.small_end.y) + 1)
        * (Int(box.big_end.z) - Int(box.small_end.z) + 1)
    )


@fieldwise_init
struct Array4F32View(TrivialRegisterPassable, DevicePassable):
    comptime device_type = Self

    var data: UnsafePointer[c_float, MutAnyOrigin]
    var lo_x: c_int
    var lo_y: c_int
    var lo_z: c_int
    var hi_x: c_int
    var hi_y: c_int
    var hi_z: c_int
    var stride_i: Int64
    var stride_j: Int64
    var stride_k: Int64
    var stride_n: Int64
    var ncomp: c_int

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](
        self,
        target: UnsafePointer[NoneType, mut_origin],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("Array4F32View")

    def offset(self, i: Int, j: Int, k: Int, comp: Int = 0) -> Int:
        return (
            (i - Int(self.lo_x)) * Int(self.stride_i)
            + (j - Int(self.lo_y)) * Int(self.stride_j)
            + (k - Int(self.lo_z)) * Int(self.stride_k)
            + comp * Int(self.stride_n)
        )

    def __getitem__(self, i: Int, j: Int, k: Int) -> Float32:
        return self.data[self.offset(i, j, k)]

    def __setitem__(self, i: Int, j: Int, k: Int, value: Float32):
        self.data[self.offset(i, j, k)] = value

    def fill(self, box: Box3D, value: Float32, comp: Int = 0):
        for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
            for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
                for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                    self.data[self.offset(i, j, k, comp)] = value


@fieldwise_init
struct TileF32View(Copyable):
    var tile_box: Box3D
    var valid_box: Box3D
    var array_view: Array4F32View

    def array(self) -> Array4F32View:
        return self.array_view.copy()

    def fill(self, value: Float32, comp: Int = 0):
        self.array_view.fill(self.tile_box, value, comp)


struct OwnedTileF32(Movable):
    var tile_box: Box3D
    var valid_box: Box3D
    var data_box: Box3D
    var storage: List[c_float]

    def __init__(out self, tile_box: Box3D, ngrow: Int = NGROW):
        self.tile_box = tile_box.copy()
        self.valid_box = tile_box.copy()
        self.data_box = grow_box(tile_box, ngrow)
        self.storage = List[c_float](
            length=box_cell_count(self.data_box), fill=0.0
        )

    def array(mut self) -> Array4F32View:
        var nx = Int(self.data_box.big_end.x) - Int(self.data_box.small_end.x) + 1
        var ny = Int(self.data_box.big_end.y) - Int(self.data_box.small_end.y) + 1
        var nz = Int(self.data_box.big_end.z) - Int(self.data_box.small_end.z) + 1
        return Array4F32View(
            data=UnsafePointer[c_float, MutAnyOrigin](self.storage.unsafe_ptr()),
            lo_x=self.data_box.small_end.x,
            lo_y=self.data_box.small_end.y,
            lo_z=self.data_box.small_end.z,
            hi_x=self.data_box.big_end.x,
            hi_y=self.data_box.big_end.y,
            hi_z=self.data_box.big_end.z,
            stride_i=1,
            stride_j=Int64(nx),
            stride_k=Int64(nx * ny),
            stride_n=Int64(nx * ny * nz),
            ncomp=1,
        )

    def tile(mut self) -> TileF32View:
        return TileF32View(
            tile_box=self.tile_box.copy(),
            valid_box=self.valid_box.copy(),
            array_view=self.array(),
        )

    def fill(mut self, value: Float32):
        self.tile().fill(value)

    def sum_valid(mut self) -> Float64:
        var array = self.array()
        var total = Float64(0.0)
        for k in range(
            Int(self.valid_box.small_end.z), Int(self.valid_box.big_end.z) + 1
        ):
            for j in range(
                Int(self.valid_box.small_end.y),
                Int(self.valid_box.big_end.y) + 1,
            ):
                for i in range(
                    Int(self.valid_box.small_end.x),
                    Int(self.valid_box.big_end.x) + 1,
                ):
                    total += Float64(array[i, j, k])
        return total


def array4_storage_size(array: Array4F32View) -> Int:
    return (
        (Int(array.hi_x) - Int(array.lo_x) + 1)
        * (Int(array.hi_y) - Int(array.lo_y) + 1)
        * (Int(array.hi_z) - Int(array.lo_z) + 1)
        * Int(array.ncomp)
    )


struct StagedArray4F32(Movable):
    var buffer: DeviceBuffer[DType.float32]
    var device_view_: Array4F32View

    def __init__(out self, ref ctx: DeviceContext, array: Array4F32View) raises:
        self.buffer = ctx.enqueue_create_buffer[DType.float32](
            array4_storage_size(array)
        )
        self.device_view_ = Array4F32View(
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

    def device_view(self) -> Array4F32View:
        return self.device_view_.copy()

    def load_from_host(
        mut self, ref ctx: DeviceContext, array: Array4F32View
    ) raises:
        ctx.enqueue_copy[DType.float32](self.buffer, array.data)

    def store_to_host(
        mut self, ref ctx: DeviceContext, array: Array4F32View
    ) raises:
        ctx.enqueue_copy[DType.float32](array.data, self.buffer)


struct StagedTileF32(Movable):
    var tile_box: Box3D
    var array_stage: StagedArray4F32

    def __init__(
        out self,
        ref ctx: DeviceContext,
        tile: TileF32View,
        load_from_host: Bool = True,
    ) raises:
        var array = tile.array()
        self.tile_box = tile.tile_box.copy()
        self.array_stage = StagedArray4F32(ctx, array)
        if load_from_host:
            self.array_stage.load_from_host(ctx, array)

    def cell_count(self) -> Int:
        return box_cell_count(self.tile_box)

    def device_view(self) -> Array4F32View:
        return self.array_stage.device_view()

    def store_to_host(
        mut self, ref ctx: DeviceContext, tile: TileF32View
    ) raises:
        self.array_stage.store_to_host(ctx, tile.array())


def fill_tile(tile: TileF32View) raises:
    tile.fill(Float32(1.0))


def update_tile_gpu(
    src: Array4F32View,
    dst: Array4F32View,
    tile_box: Box3D,
    add_value: Float32,
):
    var tid = global_idx.x
    var tile_lo_x = Int(tile_box.small_end.x)
    var tile_lo_y = Int(tile_box.small_end.y)
    var tile_lo_z = Int(tile_box.small_end.z)
    var tile_hi_x = Int(tile_box.big_end.x)
    var tile_hi_y = Int(tile_box.big_end.y)
    var tile_hi_z = Int(tile_box.big_end.z)
    var nx = tile_hi_x - tile_lo_x + 1
    var ny = tile_hi_y - tile_lo_y + 1
    var nz = tile_hi_z - tile_lo_z + 1
    var active_cells = nx * ny * nz
    if tid < UInt(active_cells):
        var linear_index = Int(tid)
        var cells_per_plane = nx * ny
        var k = tile_lo_z + linear_index // cells_per_plane
        var plane_index = linear_index % cells_per_plane
        var j = tile_lo_y + plane_index // nx
        var i = tile_lo_x + plane_index % nx
        dst[i, j, k] = src[i, j, k] + add_value


def fill_tile_gpu(
    dst: Array4F32View,
    tile_box: Box3D,
    fill_value: Float32,
):
    var tid = global_idx.x
    var tile_lo_x = Int(tile_box.small_end.x)
    var tile_lo_y = Int(tile_box.small_end.y)
    var tile_lo_z = Int(tile_box.small_end.z)
    var tile_hi_x = Int(tile_box.big_end.x)
    var tile_hi_y = Int(tile_box.big_end.y)
    var tile_hi_z = Int(tile_box.big_end.z)
    var nx = tile_hi_x - tile_lo_x + 1
    var ny = tile_hi_y - tile_lo_y + 1
    var nz = tile_hi_z - tile_lo_z + 1
    var active_cells = nx * ny * nz
    if tid < UInt(active_cells):
        var linear_index = Int(tid)
        var cells_per_plane = nx * ny
        var k = tile_lo_z + linear_index // cells_per_plane
        var plane_index = linear_index % cells_per_plane
        var j = tile_lo_y + plane_index // nx
        var i = tile_lo_x + plane_index % nx
        dst[i, j, k] = fill_value


def update_tile_with_gpu_zero_copy(
    ref ctx: DeviceContext,
    src_tile: TileF32View,
    dst_tile: TileF32View,
    add_value: Float32,
) raises:
    ctx.enqueue_function[update_tile_gpu, update_tile_gpu](
        src_tile.array(),
        dst_tile.array(),
        dst_tile.tile_box,
        add_value,
        grid_dim=ceildiv(box_cell_count(dst_tile.tile_box), KERNEL_BLOCK_SIZE),
        block_dim=KERNEL_BLOCK_SIZE,
    )
    ctx.synchronize()


def update_tile_with_gpu_staged(
    ref ctx: DeviceContext,
    src_tile: TileF32View,
    dst_tile: TileF32View,
    add_value: Float32,
) raises:
    var src_stage = StagedTileF32(ctx, src_tile, load_from_host=False)
    var dst_stage = StagedTileF32(ctx, dst_tile, load_from_host=False)
    ctx.enqueue_function[fill_tile_gpu, fill_tile_gpu](
        src_stage.device_view(),
        src_stage.tile_box,
        Float32(1.0),
        grid_dim=ceildiv(src_stage.cell_count(), KERNEL_BLOCK_SIZE),
        block_dim=KERNEL_BLOCK_SIZE,
    )
    ctx.enqueue_function[update_tile_gpu, update_tile_gpu](
        src_stage.device_view(),
        dst_stage.device_view(),
        dst_stage.tile_box,
        add_value,
        grid_dim=ceildiv(dst_stage.cell_count(), KERNEL_BLOCK_SIZE),
        block_dim=KERNEL_BLOCK_SIZE,
    )
    dst_stage.store_to_host(ctx, dst_tile)
    ctx.synchronize()


def main() raises:
    if not has_accelerator():
        raise Error(
            "issues/apple_silicon_zero_copy_host_buffer_gpu_repro.mojo requires a Mojo-supported accelerator."
        )

    var add_value = Float32(TILE_FILL_VALUE - 1)
    var expected_per_cell = Float64(TILE_FILL_VALUE)
    var source_sum = Float64(0.0)
    var zero_copy_sum = Float64(0.0)
    var staged_sum = Float64(0.0)
    var tile_count = 0
    var box_count = 0

    var ctx = DeviceContext()
    ctx.synchronize()

    for k_lo in range(0, DOMAIN_EXTENT, TILE_EXTENT):
        for j_lo in range(0, DOMAIN_EXTENT, TILE_EXTENT):
            for i_lo in range(0, DOMAIN_EXTENT, TILE_EXTENT):
                var tile_box = box3d(
                    small_end=intvect3d(i_lo, j_lo, k_lo),
                    big_end=intvect3d(
                        i_lo + TILE_EXTENT - 1,
                        j_lo + TILE_EXTENT - 1,
                        k_lo + TILE_EXTENT - 1,
                    ),
                )

                var source_tile = OwnedTileF32(tile_box)
                var zero_copy_tile = OwnedTileF32(tile_box)
                var staged_tile = OwnedTileF32(tile_box)

                fill_tile(source_tile.tile())
                zero_copy_tile.fill(Float32(0.0))
                staged_tile.fill(Float32(0.0))

                source_sum += source_tile.sum_valid()

                update_tile_with_gpu_zero_copy(
                    ctx,
                    source_tile.tile(),
                    zero_copy_tile.tile(),
                    add_value,
                )
                update_tile_with_gpu_staged(
                    ctx,
                    source_tile.tile(),
                    staged_tile.tile(),
                    add_value,
                )

                zero_copy_sum += zero_copy_tile.sum_valid()
                staged_sum += staged_tile.sum_valid()
                tile_count += 1
                box_count += 1

    var expected_sum = (
        Float64(DOMAIN_EXTENT * DOMAIN_EXTENT * DOMAIN_EXTENT)
        * expected_per_cell
    )

    print("boxes=", box_count)
    print("tiles=", tile_count)
    print("expected_sum=", expected_sum)
    print("source_sum=", source_sum)
    print("zero_copy_sum=", zero_copy_sum)
    print("staged_sum=", staged_sum)
    print("zero_copy_matches_expected=", zero_copy_sum == expected_sum)
    print("staged_matches_expected=", staged_sum == expected_sum)
