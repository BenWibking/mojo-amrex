from amrex.ffi import (
    RuntimeHandle,
    abi_version,
    last_error_message,
    parallel_ioprocessor,
    parallel_ioprocessor_number,
    parallel_myproc,
    parallel_nprocs,
    runtime_create,
    runtime_initialized,
)
from amrex.loader import default_library_path, load_library
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

    def __init__(out self) raises:
        var path = default_library_path()
        var lib = load_library(path)
        var handle = runtime_create(lib)
        if not handle:
            raise Error(last_error_message(lib))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, handle, path^))

    def __init__(out self, path: String) raises:
        var path_owned = path.copy()
        var lib = load_library(path_owned)
        var handle = runtime_create(lib)
        if not handle:
            raise Error(last_error_message(lib))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, handle, path_owned^))

    def abi_version(ref self) raises -> Int:
        return abi_version(self.state[].lib)

    def initialized(ref self) raises -> Bool:
        return runtime_initialized(self.state[].lib, self.state[].handle)

    def nprocs(ref self) raises -> Int:
        return parallel_nprocs(self.state[].lib)

    def myproc(ref self) raises -> Int:
        return parallel_myproc(self.state[].lib)

    def ioprocessor(ref self) raises -> Bool:
        return parallel_ioprocessor(self.state[].lib)

    def ioprocessor_number(ref self) raises -> Int:
        return parallel_ioprocessor_number(self.state[].lib)

    def library_path(ref self) raises -> String:
        return self.state[].path.copy()

    def _lease(ref self) raises -> RuntimeLease:
        return self.state

    def _handle(ref self) raises -> RuntimeHandle:
        return self.state[].handle
