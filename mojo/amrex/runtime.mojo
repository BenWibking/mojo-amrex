from amrex.ffi import (
    ExternalGpuStreamScopeHandle,
    GPU_BACKEND_CUDA,
    GPU_BACKEND_HIP,
    GPU_BACKEND_NONE,
    RuntimeHandle,
    abi_version,
    external_gpu_stream_scope_create,
    gpu_backend as ffi_gpu_backend,
    parallel_ioprocessor,
    parallel_ioprocessor_number,
    parallel_myproc,
    parallel_nprocs,
    last_error_message,
    runtime_create,
    runtime_initialized,
)
from amrex.loader import default_library_path, load_library
from amrex.ownership import require_live_handle
from std.collections import List
from std.ffi import OwnedDLHandle
from std.gpu.host import DeviceContext
from std.gpu.host._amdgpu_hip import HIP
from std.gpu.host._nvidia_cuda import CUDA
from std.memory import ArcPointer


@fieldwise_init
struct _AmrexRuntimeState(Movable):
    var lib: OwnedDLHandle
    var handle: RuntimeHandle
    var path: String

    def __del__(deinit self):
        if self.handle:
            self.lib.call["amrex_mojo_runtime_destroy"](self.handle)


comptime RuntimeLease = ArcPointer[_AmrexRuntimeState]


struct AmrexRuntime(Movable):
    var state: RuntimeLease
    var handle: RuntimeHandle

    def __init__(out self) raises:
        var path = default_library_path()
        var lib = load_library(path)
        var handle = runtime_create(lib)
        if not handle:
            raise Error(last_error_message(lib))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, handle, path^))
        self.handle = handle

    def __init__(
        out self, argv: List[String], use_parmparse: Bool = False
    ) raises:
        var path = default_library_path()
        var lib = load_library(path)
        var handle = runtime_create(lib, argv, use_parmparse)
        if not handle:
            raise Error(last_error_message(lib))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, handle, path^))
        self.handle = handle

    def __init__(out self, path: String) raises:
        var path_owned = path.copy()
        var lib = load_library(path_owned)
        var handle = runtime_create(lib)
        if not handle:
            raise Error(last_error_message(lib))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, handle, path_owned^))
        self.handle = handle

    def __init__(
        out self, path: String, argv: List[String], use_parmparse: Bool = False
    ) raises:
        var path_owned = path.copy()
        var lib = load_library(path_owned)
        var handle = runtime_create(lib, argv, use_parmparse)
        if not handle:
            raise Error(last_error_message(lib))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, handle, path_owned^))
        self.handle = handle

    def abi_version(ref self) raises -> Int:
        var state = self._lease()
        return abi_version(state[].lib)

    def initialized(ref self) raises -> Bool:
        var state = self._lease()
        return runtime_initialized(state[].lib, state[].handle)

    def nprocs(ref self) raises -> Int:
        var state = self._lease()
        return parallel_nprocs(state[].lib)

    def myproc(ref self) raises -> Int:
        var state = self._lease()
        return parallel_myproc(state[].lib)

    def ioprocessor(ref self) raises -> Bool:
        var state = self._lease()
        return parallel_ioprocessor(state[].lib)

    def ioprocessor_number(ref self) raises -> Int:
        var state = self._lease()
        return parallel_ioprocessor_number(state[].lib)

    def library_path(ref self) raises -> String:
        var state = self._lease()
        return state[].path.copy()

    def gpu_backend_code(ref self) raises -> Int:
        var state = self._lease()
        return ffi_gpu_backend(state[].lib)

    def gpu_backend(ref self) raises -> String:
        var backend = self.gpu_backend_code()
        if backend == GPU_BACKEND_CUDA:
            return String("cuda")
        if backend == GPU_BACKEND_HIP:
            return String("hip")
        return String("none")

    def external_gpu_stream_scope(
        ref self,
        ref ctx: DeviceContext,
        sync_on_exit: Bool = True,
    ) raises -> ExternalGpuStreamScope:
        return ExternalGpuStreamScope(self, ctx, sync_on_exit)

    def _lease(ref self) raises -> RuntimeLease:
        require_live_handle(
            self.handle,
            (
                "AmrexRuntime no longer owns a live AMReX runtime. The value"
                " may have been moved from."
            ),
        )
        return self.state

    def _handle(ref self) raises -> RuntimeHandle:
        _ = self._lease()
        return self.handle


struct ExternalGpuStreamScope(Movable):
    var runtime: RuntimeLease
    var handle: ExternalGpuStreamScopeHandle

    def __init__(
        out self,
        ref runtime: AmrexRuntime,
        ref ctx: DeviceContext,
        sync_on_exit: Bool = True,
    ) raises:
        self.runtime = runtime._lease()

        var amrex_backend = ffi_gpu_backend(self.runtime[].lib)
        var mojo_backend = ctx.api()
        if amrex_backend == GPU_BACKEND_NONE:
            raise Error(
                "The loaded AMReX library was built without GPU support."
            )
        if amrex_backend == GPU_BACKEND_CUDA and mojo_backend != "cuda":
            raise Error(
                "AMReX was built for CUDA but the active Mojo device context reports '"
                + mojo_backend
                + "'."
            )
        if amrex_backend == GPU_BACKEND_HIP and mojo_backend != "hip":
            raise Error(
                "AMReX was built for HIP but the active Mojo device context reports '"
                + mojo_backend
                + "'."
            )

        var stream_handle = _external_stream_handle(ctx, amrex_backend)
        self.handle = external_gpu_stream_scope_create(
            self.runtime[].lib,
            stream_handle,
            sync_on_exit,
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __del__(deinit self):
        if self.handle:
            self.runtime[].lib.call[
                "amrex_mojo_external_gpu_stream_scope_destroy"
            ](self.handle)


def _external_stream_handle(
    ref ctx: DeviceContext, backend: Int
) raises -> UnsafePointer[NoneType, MutExternalOrigin]:
    if backend == GPU_BACKEND_CUDA:
        return CUDA(ctx.stream()).bitcast[NoneType]()
    if backend == GPU_BACKEND_HIP:
        return HIP(ctx.stream()).bitcast[NoneType]()
    raise Error("Unsupported AMReX GPU backend for external stream interop.")
