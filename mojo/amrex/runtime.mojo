from amrex.ffi import (
    AmrexFunctionCache,
    GPU_BACKEND_CUDA,
    GPU_BACKEND_HIP,
    GPU_BACKEND_NONE,
    RuntimeHandle,
    abi_version,
    gpu_backend as ffi_gpu_backend,
    gpu_device_id as ffi_gpu_device_id,
    gpu_num_streams as ffi_gpu_num_streams,
    gpu_reset_stream as ffi_gpu_reset_stream,
    gpu_set_stream_index as ffi_gpu_set_stream_index,
    gpu_stream as ffi_gpu_stream,
    gpu_stream_synchronize_active as ffi_gpu_stream_synchronize_active,
    parallel_ioprocessor,
    parallel_ioprocessor_number,
    parallel_myproc,
    parallel_nprocs,
    last_error_message,
    runtime_create,
    runtime_destroy,
    runtime_initialized,
)
from amrex.loader import default_library_path, load_library
from amrex.ownership import require_live_handle
from std.collections import List
from std.ffi import OwnedDLHandle
from std.gpu.host import DeviceContext
from std.memory import ArcPointer


@fieldwise_init
struct _AmrexRuntimeState(Movable):
    var lib: OwnedDLHandle
    var functions: AmrexFunctionCache
    var handle: RuntimeHandle
    var path: String


comptime RuntimeLease = ArcPointer[_AmrexRuntimeState]


def require_matching_gpu_context(
    runtime: RuntimeLease,
    ref ctx: DeviceContext,
) raises -> Int:
    var amrex_backend = ffi_gpu_backend(runtime[].functions)
    var mojo_backend = ctx.api()
    if amrex_backend == GPU_BACKEND_NONE:
        raise Error("The loaded AMReX library was built without GPU support.")
    if amrex_backend == GPU_BACKEND_CUDA and mojo_backend != "cuda":
        raise Error(
            "AMReX was built for CUDA but the active Mojo device context"
            " reports '"
            + mojo_backend
            + "'."
        )
    if amrex_backend == GPU_BACKEND_HIP and mojo_backend != "hip":
        raise Error(
            "AMReX was built for HIP but the active Mojo device context"
            " reports '"
            + mojo_backend
            + "'."
        )

    var amrex_device_id = ffi_gpu_device_id(runtime[].functions)
    if amrex_device_id < 0:
        raise Error(
            "The loaded AMReX runtime does not report an active GPU device."
        )
    if Int(ctx.id()) != amrex_device_id:
        raise Error(
            "AMReX and the active Mojo device context are using different"
            " GPU devices."
            + " Construct `AmrexRuntime` on the same device as `ctx` before"
            + " sharing streams."
        )
    return amrex_backend


@explicit_destroy("Must call close() on AmrexRuntime")
struct AmrexRuntime(Movable):
    var state: RuntimeLease
    var handle: RuntimeHandle

    def __init__(out self) raises:
        var path = default_library_path()
        var lib = load_library(path)
        var functions = AmrexFunctionCache(lib)
        var handle = runtime_create(functions)
        if not handle:
            raise Error(last_error_message(functions))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, functions^, handle, path^))
        self.handle = handle

    def __init__(
        out self, argv: List[String], use_parmparse: Bool = False
    ) raises:
        var path = default_library_path()
        var lib = load_library(path)
        var functions = AmrexFunctionCache(lib)
        var handle = runtime_create(lib, argv, use_parmparse)
        if not handle:
            raise Error(last_error_message(functions))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, functions^, handle, path^))
        self.handle = handle

    def __init__(out self, path: String) raises:
        var path_owned = path.copy()
        var lib = load_library(path_owned)
        var functions = AmrexFunctionCache(lib)
        var handle = runtime_create(functions)
        if not handle:
            raise Error(last_error_message(functions))
        self.state = RuntimeLease(
            _AmrexRuntimeState(lib^, functions^, handle, path_owned^)
        )
        self.handle = handle

    def __init__(
        out self, path: String, argv: List[String], use_parmparse: Bool = False
    ) raises:
        var path_owned = path.copy()
        var lib = load_library(path_owned)
        var functions = AmrexFunctionCache(lib)
        var handle = runtime_create(lib, argv, use_parmparse)
        if not handle:
            raise Error(last_error_message(functions))
        self.state = RuntimeLease(
            _AmrexRuntimeState(lib^, functions^, handle, path_owned^)
        )
        self.handle = handle

    def __init__(out self, device_id: Int) raises:
        var path = default_library_path()
        var lib = load_library(path)
        var functions = AmrexFunctionCache(lib)
        var handle = runtime_create(functions, device_id)
        if not handle:
            raise Error(last_error_message(functions))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, functions^, handle, path^))
        self.handle = handle

    def __init__(
        out self,
        device_id: Int,
        argv: List[String],
        use_parmparse: Bool = False,
    ) raises:
        var path = default_library_path()
        var lib = load_library(path)
        var functions = AmrexFunctionCache(lib)
        var handle = runtime_create(lib, argv, use_parmparse, device_id)
        if not handle:
            raise Error(last_error_message(functions))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, functions^, handle, path^))
        self.handle = handle

    def __init__(out self, path: String, device_id: Int) raises:
        var path_owned = path.copy()
        var lib = load_library(path_owned)
        var functions = AmrexFunctionCache(lib)
        var handle = runtime_create(functions, device_id)
        if not handle:
            raise Error(last_error_message(functions))
        self.state = RuntimeLease(
            _AmrexRuntimeState(lib^, functions^, handle, path_owned^)
        )
        self.handle = handle

    def __init__(
        out self,
        path: String,
        device_id: Int,
        argv: List[String],
        use_parmparse: Bool = False,
    ) raises:
        var path_owned = path.copy()
        var lib = load_library(path_owned)
        var functions = AmrexFunctionCache(lib)
        var handle = runtime_create(lib, argv, use_parmparse, device_id)
        if not handle:
            raise Error(last_error_message(functions))
        self.state = RuntimeLease(
            _AmrexRuntimeState(lib^, functions^, handle, path_owned^)
        )
        self.handle = handle

    def abi_version(ref self) raises -> Int:
        var state = self._lease()
        return abi_version(state[].functions)

    def initialized(ref self) raises -> Bool:
        var state = self._lease()
        return runtime_initialized(state[].functions, state[].handle)

    def nprocs(ref self) raises -> Int:
        var state = self._lease()
        return parallel_nprocs(state[].functions)

    def myproc(ref self) raises -> Int:
        var state = self._lease()
        return parallel_myproc(state[].functions)

    def ioprocessor(ref self) raises -> Bool:
        var state = self._lease()
        return parallel_ioprocessor(state[].functions)

    def ioprocessor_number(ref self) raises -> Int:
        var state = self._lease()
        return parallel_ioprocessor_number(state[].functions)

    def library_path(ref self) raises -> String:
        var state = self._lease()
        return state[].path.copy()

    def gpu_backend_code(ref self) raises -> Int:
        var state = self._lease()
        return ffi_gpu_backend(state[].functions)

    def gpu_backend(ref self) raises -> String:
        var backend = self.gpu_backend_code()
        if backend == GPU_BACKEND_CUDA:
            return String("cuda")
        if backend == GPU_BACKEND_HIP:
            return String("hip")
        return String("none")

    def gpu_device_id(ref self) raises -> Int:
        var state = self._lease()
        return ffi_gpu_device_id(state[].functions)

    def gpu_num_streams(ref self) raises -> Int:
        var state = self._lease()
        return ffi_gpu_num_streams(state[].functions)

    def gpu_set_stream_index(ref self, stream_index: Int) raises:
        var state = self._lease()
        if ffi_gpu_set_stream_index(state[].functions, stream_index) != 0:
            raise Error(last_error_message(state[].functions))

    def gpu_reset_stream(ref self) raises:
        var state = self._lease()
        ffi_gpu_reset_stream(state[].functions)

    def gpu_stream_handle(
        ref self, ref ctx: DeviceContext
    ) raises -> UnsafePointer[NoneType, MutExternalOrigin]:
        var state = self._lease()
        _ = require_matching_gpu_context(state, ctx)
        var handle = ffi_gpu_stream(state[].functions)
        if not handle:
            raise Error(last_error_message(state[].functions))
        return handle

    def gpu_synchronize_active_streams(ref self) raises:
        var state = self._lease()
        if ffi_gpu_stream_synchronize_active(state[].functions) != 0:
            raise Error(last_error_message(state[].functions))

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

    def close(deinit self):
        if self.handle:
            self.state[].functions.runtime_destroy_fn(self.handle)
