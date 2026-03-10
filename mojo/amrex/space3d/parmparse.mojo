"""`ParmParse` wrapper for the 3D binding layer."""

from amrex.ffi import (
    ParmParseHandle,
    last_error_message,
    parmparse_add_int,
    parmparse_create,
    parmparse_query_int,
)
from amrex.runtime import AmrexRuntime, RuntimeLease


struct ParmParse(Movable):
    var runtime: RuntimeLease
    var handle: ParmParseHandle

    def __init__(
        out self, ref runtime: AmrexRuntime, prefix: StringLiteral = ""
    ) raises:
        self.runtime = runtime._lease()
        self.handle = parmparse_create(
            self.runtime[].lib, self.runtime[].handle, prefix
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __init__(out self, ref runtime: AmrexRuntime, prefix: String) raises:
        self.runtime = runtime._lease()
        self.handle = parmparse_create(
            self.runtime[].lib, self.runtime[].handle, prefix
        )
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    fn __del__(deinit self):
        if self.handle:
            self.runtime[].lib.call["amrex_mojo_parmparse_destroy"](self.handle)

    def add_int(mut self, name: String, value: Int) raises:
        if parmparse_add_int(self.runtime[].lib, self.handle, name, value) != 0:
            raise Error(last_error_message(self.runtime[].lib))

    def add_int(mut self, name: StringLiteral, value: Int) raises:
        self.add_int(String(name), value)

    def query_int(ref self, name: String) raises -> Int:
        var result = parmparse_query_int(self.runtime[].lib, self.handle, name)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        if not result.found:
            raise Error("ParmParse integer value was not found.")
        return result.value

    def query_int(ref self, name: StringLiteral) raises -> Int:
        return self.query_int(String(name))

    def query_int_or(ref self, name: String, default_value: Int) raises -> Int:
        var result = parmparse_query_int(self.runtime[].lib, self.handle, name)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        if not result.found:
            return default_value
        return result.value

    def query_int_or(
        ref self, name: StringLiteral, default_value: Int
    ) raises -> Int:
        return self.query_int_or(String(name), default_value)

    def _handle(ref self) raises -> ParmParseHandle:
        return self.handle
