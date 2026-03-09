#include "capi_internal.H"

extern "C" amrex_mojo_status_code_t
amrex_mojo_mfiter_create(amrex_mojo_multifab_t* multifab, amrex_mojo_mfiter_t** out_mfiter)
{
    if (multifab == nullptr || out_mfiter == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "mfiter_create requires non-null pointers."
        );
    }

    *out_mfiter = nullptr;
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_mfiter_create is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t amrex_mojo_mfiter_destroy(amrex_mojo_mfiter_t* mfiter)
{
    (void)mfiter;
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" int32_t amrex_mojo_mfiter_is_valid(const amrex_mojo_mfiter_t* mfiter)
{
    (void)mfiter;
    amrex_mojo::detail::clear_last_error();
    return 0;
}

extern "C" amrex_mojo_status_code_t amrex_mojo_mfiter_next(amrex_mojo_mfiter_t* mfiter)
{
    if (mfiter == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "mfiter_next requires a non-null iterator."
        );
    }

    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_mfiter_next is not implemented yet."
    );
}
