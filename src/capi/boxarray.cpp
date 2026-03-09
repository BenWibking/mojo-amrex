#include "capi_internal.H"

extern "C" amrex_mojo_status_code_t
amrex_mojo_boxarray_create_from_box(
    const amrex_mojo_box_3d* domain,
    amrex_mojo_boxarray_t** out_boxarray
)
{
    if (domain == nullptr || out_boxarray == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_create_from_box requires non-null pointers."
        );
    }

    *out_boxarray = nullptr;
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_boxarray_create_from_box is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t amrex_mojo_boxarray_destroy(amrex_mojo_boxarray_t* boxarray)
{
    (void)boxarray;
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_boxarray_max_size(
    amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_intvect_3d* max_size
)
{
    if (boxarray == nullptr || max_size == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_max_size requires non-null pointers."
        );
    }

    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_boxarray_max_size is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_boxarray_size(const amrex_mojo_boxarray_t* boxarray, int64_t* out_size)
{
    if (boxarray == nullptr || out_size == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_size requires non-null pointers."
        );
    }

    *out_size = 0;
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_boxarray_size is not implemented yet."
    );
}
