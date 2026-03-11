from amrex.ffi import (
    RuntimeHandle,
    abi_version,
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
from std.memory import ArcPointer


@fieldwise_init
struct _AmrexRuntimeState(Movable):
    var lib: OwnedDLHandle
    var handle: RuntimeHandle
    var path: String

    fn __del__(deinit self):
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
