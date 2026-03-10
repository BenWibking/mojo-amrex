"""Shared ownership and moved-from diagnostics for AMReX wrappers."""


def require_live_handle(
    handle: UnsafePointer[NoneType, MutExternalOrigin], message: StringLiteral
) raises:
    if not handle:
        raise Error(message)
