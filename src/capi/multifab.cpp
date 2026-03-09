#include "capi_internal.H"

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_create(
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    const amrex_mojo_intvect_3d* ngrow,
    amrex_mojo_multifab_t** out_multifab
)
{
    if (boxarray == nullptr || distmap == nullptr || ngrow == nullptr || out_multifab == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_create requires non-null pointers."
        );
    }

    if (ncomp <= 0) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_create requires ncomp > 0."
        );
    }

    *out_multifab = nullptr;
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_multifab_create is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t amrex_mojo_multifab_destroy(amrex_mojo_multifab_t* multifab)
{
    (void)multifab;
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_ncomp(const amrex_mojo_multifab_t* multifab, int32_t* out_ncomp)
{
    if (multifab == nullptr || out_ncomp == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_ncomp requires non-null pointers."
        );
    }

    *out_ncomp = 0;
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_multifab_ncomp is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_set_val(
    amrex_mojo_multifab_t* multifab,
    double value,
    int32_t start_comp,
    int32_t ncomp
)
{
    (void)value;
    (void)start_comp;
    (void)ncomp;

    if (multifab == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_set_val requires a non-null multifab."
        );
    }

    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_multifab_set_val is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_array4(
    amrex_mojo_multifab_t* multifab,
    amrex_mojo_mfiter_t* mfiter,
    amrex_mojo_array4_view_f64* out_view
)
{
    if (multifab == nullptr || mfiter == nullptr || out_view == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_array4 requires non-null pointers."
        );
    }

    *out_view = {};
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_multifab_array4 is not implemented yet."
    );
}
