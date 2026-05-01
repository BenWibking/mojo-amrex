"""Shared ownership and moved-from diagnostics for AMReX wrappers."""


def require_live_handle(
    handle: Optional[UnsafePointer[NoneType, MutExternalOrigin]],
    message: StringLiteral,
) raises -> UnsafePointer[NoneType, MutExternalOrigin]:
    if not handle:
        raise Error(message)
    return handle.value()
