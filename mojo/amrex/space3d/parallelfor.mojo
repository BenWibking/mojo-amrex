"""`ParallelFor` helpers for 3D tile boxes."""

from amrex.ffi import (
    Box3D,
    GPU_BACKEND_CUDA,
    GPU_BACKEND_HIP,
    GPU_BACKEND_NONE,
    gpu_backend,
    gpu_device_id,
    gpu_stream,
    last_error_message,
)
from amrex.build_config import AMREX_MOJO_HAS_COMPILED_GPU_BACKEND
from amrex.loader import load_default_library
from std.builtin.device_passable import DevicePassable
from std.gpu import global_idx
from std.gpu.host import DeviceContext, DeviceStream
from std.math import ceildiv
from std.sys import has_accelerator


comptime KERNEL_BLOCK_SIZE = 256
comptime AMREX_MOJO_CAN_COMPILE_GPU_PARALLEL_FOR = AMREX_MOJO_HAS_COMPILED_GPU_BACKEND and has_accelerator()


def _cell_count(tile_box: Box3D) -> Int:
    return (
        (Int(tile_box.big_end.x) - Int(tile_box.small_end.x) + 1)
        * (Int(tile_box.big_end.y) - Int(tile_box.small_end.y) + 1)
        * (Int(tile_box.big_end.z) - Int(tile_box.small_end.z) + 1)
    )


def _parallel_for_cpu[
    body_type: (def(Int, Int, Int) register_passable -> None) & DevicePassable
](body: body_type, tile_box: Box3D) raises:
    for k in range(Int(tile_box.small_end.z), Int(tile_box.big_end.z) + 1):
        for j in range(Int(tile_box.small_end.y), Int(tile_box.big_end.y) + 1):
            for i in range(Int(tile_box.small_end.x), Int(tile_box.big_end.x) + 1):
                body(i, j, k)


def ParallelForCpu[
    body_type: (def(Int, Int, Int) register_passable -> None) & DevicePassable
](body: body_type, tile_box: Box3D) raises:
    _parallel_for_cpu(body, tile_box)


def _parallel_for_kernel[
    body_type: (def(Int, Int, Int) register_passable -> None) & DevicePassable
](body: body_type, tile_box: Box3D):
    var tid = global_idx.x
    var lo_x = Int(tile_box.small_end.x)
    var lo_y = Int(tile_box.small_end.y)
    var lo_z = Int(tile_box.small_end.z)
    var nx = Int(tile_box.big_end.x) - lo_x + 1
    var ny = Int(tile_box.big_end.y) - lo_y + 1
    var active_cells = _cell_count(tile_box)
    if tid < active_cells:
        var linear_index = Int(tid)
        var cells_per_plane = nx * ny
        var k = lo_z + linear_index // cells_per_plane
        var plane_index = linear_index % cells_per_plane
        var j = lo_y + plane_index // nx
        var i = lo_x + plane_index % nx
        body(i, j, k)


def _gpu_context(backend: Int, device_id: Int) raises -> DeviceContext:
    var ctx = DeviceContext()
    if backend == GPU_BACKEND_CUDA and ctx.api() != "cuda":
        raise Error("AMReX was built for CUDA, but the active Mojo device context is not CUDA.")
    if backend == GPU_BACKEND_HIP and ctx.api() != "hip":
        raise Error("AMReX was built for HIP, but the active Mojo device context is not HIP.")
    if Int(ctx.id()) != device_id:
        raise Error("AMReX and the active Mojo device context are using different GPU devices.")
    return ctx


def ParallelFor[
    body_type: (def(Int, Int, Int) register_passable -> None) & DevicePassable
](body: body_type, tile_box: Box3D) raises:
    comptime if not AMREX_MOJO_CAN_COMPILE_GPU_PARALLEL_FOR:
        _parallel_for_cpu(body, tile_box)
        return

    var lib = load_default_library()
    var backend = gpu_backend(lib)
    if backend == GPU_BACKEND_NONE:
        _parallel_for_cpu(body, tile_box)
        return

    if not has_accelerator():
        raise Error("AMReX has a GPU backend, but Mojo did not find a supported accelerator.")

    var device_id = gpu_device_id(lib)
    if device_id < 0:
        raise Error("AMReX has a GPU backend, but no active GPU device is available.")

    var handle = gpu_stream(lib)
    if not handle:
        raise Error(last_error_message(lib))

    var ctx = _gpu_context(backend, device_id)
    var stream = ctx.create_external_stream(handle.value())
    ParallelFor(ctx, stream, body, tile_box)


def ParallelFor[
    body_type: (def(Int, Int, Int) register_passable -> None) & DevicePassable
](ref ctx: DeviceContext, ref stream: DeviceStream, body: body_type, tile_box: Box3D) raises:
    var kernel = ctx.compile_function[_parallel_for_kernel[body_type]]()
    stream.enqueue_function(
        kernel,
        body,
        tile_box,
        grid_dim=ceildiv(_cell_count(tile_box), KERNEL_BLOCK_SIZE),
        block_dim=KERNEL_BLOCK_SIZE,
    )
