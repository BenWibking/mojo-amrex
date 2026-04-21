"""`ParmParse` wrapper for the 3D binding layer."""

from amrex.ffi import (
    ParmParseHandle,
    last_error_message,
    parmparse_add_int,
    parmparse_create,
    parmparse_destroy,
    parmparse_query_int,
    parmparse_query_real,
)
from amrex.ownership import require_live_handle
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

    def __del__(deinit self):
        if self.handle:
            self.runtime[].functions.parmparse_destroy_fn(self.handle)

    def add_int(mut self, name: String, value: Int) raises:
        var handle = self._handle()
        if parmparse_add_int(self.runtime[].lib, handle, name, value) != 0:
            raise Error(last_error_message(self.runtime[].lib))

    def add_int(mut self, name: StringLiteral, value: Int) raises:
        self.add_int(String(name), value)

    def query_int(ref self, name: String) raises -> Int:
        var handle = self._handle()
        var result = parmparse_query_int(self.runtime[].lib, handle, name)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        if not result.found:
            raise Error("ParmParse integer value was not found.")
        return result.value

    def query_int(ref self, name: StringLiteral) raises -> Int:
        return self.query_int(String(name))

    def get_int(ref self, name: String) raises -> Int:
        return self.query_int(name)

    def get_int(ref self, name: StringLiteral) raises -> Int:
        return self.get_int(String(name))

    def query_int_or(ref self, name: String, default_value: Int) raises -> Int:
        var handle = self._handle()
        var result = parmparse_query_int(self.runtime[].lib, handle, name)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        if not result.found:
            return default_value
        return result.value

    def query_int_or(
        ref self, name: StringLiteral, default_value: Int
    ) raises -> Int:
        return self.query_int_or(String(name), default_value)

    def query_real(ref self, name: String) raises -> Float64:
        var handle = self._handle()
        var result = parmparse_query_real(self.runtime[].lib, handle, name)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        if not result.found:
            raise Error("ParmParse real value was not found.")
        return result.value

    def query_real(ref self, name: StringLiteral) raises -> Float64:
        return self.query_real(String(name))

    def get_real(ref self, name: String) raises -> Float64:
        return self.query_real(name)

    def get_real(ref self, name: StringLiteral) raises -> Float64:
        return self.get_real(String(name))

    def query_real_or(
        ref self, name: String, default_value: Float64
    ) raises -> Float64:
        var handle = self._handle()
        var result = parmparse_query_real(self.runtime[].lib, handle, name)
        if result.status != 0:
            raise Error(last_error_message(self.runtime[].lib))
        if not result.found:
            return default_value
        return result.value

    def query_real_or(
        ref self, name: StringLiteral, default_value: Float64
    ) raises -> Float64:
        return self.query_real_or(String(name), default_value)

    def _handle(ref self) raises -> ParmParseHandle:
        require_live_handle(
            self.handle,
            (
                "ParmParse no longer owns a live AMReX handle. The value may"
                " have been moved from."
            ),
        )
        return self.handle
