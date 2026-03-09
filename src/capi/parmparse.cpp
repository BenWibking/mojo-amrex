#include "capi_internal.H"

extern "C" amrex_mojo_parmparse_t*
amrex_mojo_parmparse_create(amrex_mojo_runtime_t* runtime, const char* prefix)
{
    if (runtime == nullptr || runtime->state == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "parmparse_create requires a live runtime."
        );
        return nullptr;
    }

    auto* state = amrex_mojo::detail::retain_runtime(runtime->state);
    try {
        auto* parmparse = new amrex_mojo_parmparse{
            state,
            std::make_unique<amrex::ParmParse>(std::string(prefix != nullptr ? prefix : ""))
        };
        amrex_mojo::detail::clear_last_error();
        return parmparse;
    } catch (const std::exception& ex) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
        return nullptr;
    } catch (...) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "parmparse_create failed with an unknown exception."
        );
        return nullptr;
    }
}

extern "C" void amrex_mojo_parmparse_destroy(amrex_mojo_parmparse_t* parmparse)
{
    if (parmparse == nullptr) {
        amrex_mojo::detail::clear_last_error();
        return;
    }

    auto* state = parmparse->state;
    delete parmparse;
    amrex_mojo::detail::release_runtime(state);
    amrex_mojo::detail::clear_last_error();
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_parmparse_add_int(amrex_mojo_parmparse_t* parmparse, const char* name, int32_t value)
{
    if (parmparse == nullptr || parmparse->value == nullptr || name == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "parmparse_add_int requires non-null pointers."
        );
    }

    try {
        parmparse->value->add(name, value);
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "parmparse_add_int failed with an unknown exception."
        );
    }
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_parmparse_query_int(
    amrex_mojo_parmparse_t* parmparse,
    const char* name,
    int32_t* out_value,
    int32_t* out_found
)
{
    if (parmparse == nullptr || parmparse->value == nullptr || name == nullptr || out_value == nullptr ||
        out_found == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "parmparse_query_int requires non-null pointers."
        );
    }

    try {
        *out_value = 0;
        *out_found = parmparse->value->query(name, *out_value) ? 1 : 0;
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "parmparse_query_int failed with an unknown exception."
        );
    }
}
