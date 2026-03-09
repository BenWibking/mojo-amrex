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


struct AmrexRuntime(Movable):
    var lib: OwnedDLHandle
    var handle: RuntimeHandle
    var path: String

    fn __init__(out self) raises:
        self.path = default_library_path()
        self.lib = load_library(self.path)
        self.handle = runtime_create(self.lib)
        if not self.handle:
            raise Error(last_error_message(self.lib))

    fn __init__(out self, path: String) raises:
        self.path = path
        self.lib = load_library(self.path)
        self.handle = runtime_create(self.lib)
        if not self.handle:
            raise Error(last_error_message(self.lib))

    fn __del__(deinit self):
        if self.handle:
            runtime_destroy(self.lib, self.handle)

    fn abi_version(ref self) -> Int:
        return abi_version(self.lib)

    fn initialized(ref self) -> Bool:
        return runtime_initialized(self.lib, self.handle)

    fn nprocs(ref self) -> Int:
        return parallel_nprocs(self.lib)

    fn myproc(ref self) -> Int:
        return parallel_myproc(self.lib)

    fn ioprocessor(ref self) -> Bool:
        return parallel_ioprocessor(self.lib)

    fn ioprocessor_number(ref self) -> Int:
        return parallel_ioprocessor_number(self.lib)

    fn library_path(ref self) -> String:
        return self.path.copy()

    fn _handle(ref self) -> RuntimeHandle:
        return self.handle
