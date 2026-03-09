#include "capi_internal.H"

extern "C" amrex_mojo_status_code_t
amrex_mojo_distmap_create_from_boxarray(
    const amrex_mojo_boxarray_t* boxarray,
    amrex_mojo_distmap_t** out_distmap
)
{
    if (boxarray == nullptr || out_distmap == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "distmap_create_from_boxarray requires non-null pointers."
        );
    }

    *out_distmap = nullptr;
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_distmap_create_from_boxarray is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t amrex_mojo_distmap_destroy(amrex_mojo_distmap_t* distmap)
{
    (void)distmap;
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}
