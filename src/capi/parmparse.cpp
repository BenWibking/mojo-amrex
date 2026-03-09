#include "capi_internal.H"

extern "C" amrex_mojo_status_code_t
amrex_mojo_parmparse_create(const char* prefix, amrex_mojo_parmparse_t** out_parmparse)
{
    (void)prefix;

    if (out_parmparse == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "parmparse_create requires a non-null output pointer."
        );
    }

    *out_parmparse = nullptr;
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_parmparse_create is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t amrex_mojo_parmparse_destroy(amrex_mojo_parmparse_t* parmparse)
{
    (void)parmparse;
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_parmparse_add_int(
    amrex_mojo_parmparse_t* parmparse,
    const char* name,
    int32_t value
)
{
    (void)value;

    if (parmparse == nullptr || name == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "parmparse_add_int requires non-null pointers."
        );
    }

    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_parmparse_add_int is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_parmparse_query_int(
    amrex_mojo_parmparse_t* parmparse,
    const char* name,
    int32_t* out_value,
    int32_t* out_found
)
{
    if (parmparse == nullptr || name == nullptr || out_value == nullptr || out_found == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "parmparse_query_int requires non-null pointers."
        );
    }

    *out_value = 0;
    *out_found = 0;
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_parmparse_query_int is not implemented yet."
    );
}
