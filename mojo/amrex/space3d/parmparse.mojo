"""`ParmParse` wrapper for the 3D binding layer."""

from amrex.ffi import (
    ParmParseHandle,
    last_error_message,
    parmparse_add_int,
    parmparse_create,
    parmparse_destroy,
    parmparse_query_int,
)
from amrex.loader import load_library
from amrex.runtime import AmrexRuntime
from std.ffi import OwnedDLHandle


struct ParmParse(Movable):
    var lib: OwnedDLHandle
    var handle: ParmParseHandle

    fn __init__(
        out self, ref runtime: AmrexRuntime, prefix: StringLiteral = ""
    ) raises:
        var path = runtime.library_path()
        self.lib = load_library(path)
        self.handle = parmparse_create(self.lib, runtime._handle(), prefix)
        if not self.handle:
            raise Error(last_error_message(self.lib))

    fn __del__(deinit self):
        if self.handle:
            parmparse_destroy(self.lib, self.handle)

    fn add_int(mut self, name: StringLiteral, value: Int) raises:
        if parmparse_add_int(self.lib, self.handle, name, value) != 0:
            raise Error(last_error_message(self.lib))

    fn query_int(ref self, name: StringLiteral) raises -> Int:
        var result = parmparse_query_int(self.lib, self.handle, name)
        if result.status != 0:
            raise Error(last_error_message(self.lib))
        if not result.found:
            raise Error("ParmParse integer value was not found.")
        return result.value

    fn query_int_or(
        ref self, name: StringLiteral, default_value: Int
    ) raises -> Int:
        var result = parmparse_query_int(self.lib, self.handle, name)
        if result.status != 0:
            raise Error(last_error_message(self.lib))
        if not result.found:
            return default_value
        return result.value

    fn _handle(ref self) -> ParmParseHandle:
        return self.handle
