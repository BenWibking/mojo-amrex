from amrex.ffi import (
    RuntimeHandle,
    abi_version,
    last_error_message,
    parallel_ioprocessor,
    parallel_ioprocessor_number,
    parallel_myproc,
    parallel_nprocs,
    runtime_create,
    runtime_destroy,
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
            runtime_destroy(self.lib, self.handle)


comptime RuntimeLease = ArcPointer[_AmrexRuntimeState]


struct AmrexRuntime(Movable):
    var state: RuntimeLease

    fn __init__(out self) raises:
        var path = default_library_path()
        var lib = load_library(path)
        var handle = runtime_create(lib)
        if not handle:
            raise Error(last_error_message(lib))
        self.state = RuntimeLease(_AmrexRuntimeState(lib^, handle, path^))

    fn __init__(out self, path: String) raises:
        var path_owned = path.copy()
        var lib = load_library(path_owned)
        var handle = runtime_create(lib)
        if not handle:
            raise Error(last_error_message(lib))
        self.state = RuntimeLease(
            _AmrexRuntimeState(lib^, handle, path_owned^)
        )

    fn abi_version(ref self) -> Int:
        return abi_version(self.state[].lib)

    fn initialized(ref self) -> Bool:
        return runtime_initialized(self.state[].lib, self.state[].handle)

    fn nprocs(ref self) -> Int:
        return parallel_nprocs(self.state[].lib)

    fn myproc(ref self) -> Int:
        return parallel_myproc(self.state[].lib)

    fn ioprocessor(ref self) -> Bool:
        return parallel_ioprocessor(self.state[].lib)

    fn ioprocessor_number(ref self) -> Int:
        return parallel_ioprocessor_number(self.state[].lib)

    fn library_path(ref self) -> String:
        return self.state[].path.copy()

    fn _lease(ref self) -> RuntimeLease:
        return self.state

    fn _handle(ref self) -> RuntimeHandle:
        return self.state[].handle
