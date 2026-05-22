"""Shared ownership and moved-from diagnostics for AMReX wrappers."""

from std.ffi import OwnedDLHandle


comptime AmrexRawHandle = UnsafePointer[NoneType, MutExternalOrigin]


def require_live_handle(
    handle: Optional[AmrexRawHandle],
    message: String,
) raises -> AmrexRawHandle:
    if not handle:
        raise Error(message)
    return handle.value()


trait AmrexHandle:
    """Owning AMReX wrapper bound to a shared runtime lease.

    Conforming structs must provide `_optional_handle()` and declare
    `moved_from_message` and `destroy_symbol` comptime members.
    Default `_handle()` centralizes moved-from checks.
    """

    comptime moved_from_message: String
    comptime destroy_symbol: String

    def _optional_handle(ref self) -> Optional[AmrexRawHandle]:
        ...

    def _handle(ref self) raises -> AmrexRawHandle:
        return require_live_handle(self._optional_handle(), Self.moved_from_message)


def destroy_amrex_optional_handle[
    destroy_symbol: StringLiteral
](ref lib: OwnedDLHandle, handle: Optional[AmrexRawHandle],):
    if handle:
        lib.call[destroy_symbol](handle.value())
