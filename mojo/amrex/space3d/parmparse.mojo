# ABOUTME: ParmParse wrapper for AMReX runtime parameter tables.
# ABOUTME: Supports querying and adding integer and real parameters.

"""`ParmParse` wrapper for the 3D binding layer."""

from amrex.ffi import (
    ParmParseHandle,
    OptionalParmParseHandle,
    last_error_message,
    parmparse_add_int,
    parmparse_create,
    parmparse_query_int,
    parmparse_query_real,
    raise_on_error,
)
from amrex.ownership import AmrexHandle, AmrexRawHandle, destroy_amrex_optional_handle
from amrex.runtime import AmrexRuntime, RuntimeLease
from std.ffi import OwnedDLHandle


trait ReadableParmValue:
    comptime value_type: AnyType

    @staticmethod
    def query_required(ref lib: OwnedDLHandle, handle: ParmParseHandle, name: String) raises -> Self.value_type:
        ...

    @staticmethod
    def query_or(
        ref lib: OwnedDLHandle,
        handle: ParmParseHandle,
        name: String,
        default_value: Self.value_type,
    ) raises -> Self.value_type:
        ...


trait WritableParmValue(ReadableParmValue):
    @staticmethod
    def add(
        ref lib: OwnedDLHandle,
        handle: ParmParseHandle,
        name: String,
        value: Self.value_type,
    ) raises:
        ...


struct ParmInt(WritableParmValue):
    comptime value_type = Int

    @staticmethod
    def add(
        ref lib: OwnedDLHandle,
        handle: ParmParseHandle,
        name: String,
        value: Int,
    ) raises:
        raise_on_error(lib, parmparse_add_int(lib, handle, name, value))

    @staticmethod
    def query_required(ref lib: OwnedDLHandle, handle: ParmParseHandle, name: String) raises -> Int:
        var result = parmparse_query_int(lib, handle, name)
        raise_on_error(lib, result.status)
        if not result.found:
            raise Error("ParmParse integer value was not found.")
        return result.value

    @staticmethod
    def query_or(
        ref lib: OwnedDLHandle,
        handle: ParmParseHandle,
        name: String,
        default_value: Int,
    ) raises -> Int:
        var result = parmparse_query_int(lib, handle, name)
        raise_on_error(lib, result.status)
        if not result.found:
            return default_value
        return result.value


struct ParmReal(ReadableParmValue):
    comptime value_type = Float64

    @staticmethod
    def query_required(ref lib: OwnedDLHandle, handle: ParmParseHandle, name: String) raises -> Float64:
        var result = parmparse_query_real(lib, handle, name)
        raise_on_error(lib, result.status)
        if not result.found:
            raise Error("ParmParse real value was not found.")
        return result.value

    @staticmethod
    def query_or(
        ref lib: OwnedDLHandle,
        handle: ParmParseHandle,
        name: String,
        default_value: Float64,
    ) raises -> Float64:
        var result = parmparse_query_real(lib, handle, name)
        raise_on_error(lib, result.status)
        if not result.found:
            return default_value
        return result.value


struct ParmParse(AmrexHandle, Movable):
    comptime moved_from_message = "ParmParse no longer owns a live AMReX handle. The value may have been moved from."
    comptime destroy_symbol = "amrex_mojo_parmparse_destroy"
    var runtime: RuntimeLease
    var handle: OptionalParmParseHandle

    def __init__(out self, ref runtime: AmrexRuntime, prefix: StringLiteral = "") raises:
        self.runtime = runtime._lease()
        self.handle = parmparse_create(self.runtime[].lib, self.runtime[].handle, prefix)
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __init__(out self, ref runtime: AmrexRuntime, prefix: String) raises:
        self.runtime = runtime._lease()
        self.handle = parmparse_create(self.runtime[].lib, self.runtime[].handle, prefix)
        if not self.handle:
            raise Error(last_error_message(self.runtime[].lib))

    def __del__(deinit self):
        destroy_amrex_optional_handle[Self.destroy_symbol](self.runtime[].lib, self.handle)

    def _optional_handle(ref self) -> Optional[AmrexRawHandle]:
        return self.handle

    def add[T: WritableParmValue](mut self, name: String, value: T.value_type) raises:
        var handle = self._handle()
        T.add(self.runtime[].lib, handle, name, value)

    def add[T: WritableParmValue](mut self, name: StringLiteral, value: T.value_type) raises:
        self.add[T](String(name), value)

    def query[T: ReadableParmValue](ref self, name: String) raises -> T.value_type:
        var handle = self._handle()
        return T.query_required(self.runtime[].lib, handle, name)

    def query[T: ReadableParmValue](ref self, name: StringLiteral) raises -> T.value_type:
        return self.query[T](String(name))

    def get[T: ReadableParmValue](ref self, name: String) raises -> T.value_type:
        return self.query[T](name)

    def get[T: ReadableParmValue](ref self, name: StringLiteral) raises -> T.value_type:
        return self.get[T](String(name))

    def query_or[T: ReadableParmValue](ref self, name: String, default_value: T.value_type) raises -> T.value_type:
        var handle = self._handle()
        return T.query_or(self.runtime[].lib, handle, name, default_value)

    def query_or[
        T: ReadableParmValue
    ](ref self, name: StringLiteral, default_value: T.value_type) raises -> T.value_type:
        return self.query_or[T](String(name), default_value)
