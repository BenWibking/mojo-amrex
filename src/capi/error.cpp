#include "capi_internal.H"

#include <string>

namespace
{
    thread_local std::string g_last_error;
}

extern "C" int32_t amrex_mojo_abi_version(void)
{
    return AMREX_MOJO_ABI_VERSION;
}

extern "C" const char* amrex_mojo_last_error_message(void)
{
    return g_last_error.c_str();
}

namespace amrex_mojo::detail
{
    void clear_last_error() noexcept
    {
        g_last_error.clear();
    }

    amrex_mojo_status_code_t
    set_last_error(amrex_mojo_status_code_t code, const char* message) noexcept
    {
        g_last_error = (message != nullptr) ? message : "";
        return code;
    }

    amrex_mojo_status_code_t
    set_last_error(amrex_mojo_status_code_t code, const std::string& message) noexcept
    {
        g_last_error = message;
        return code;
    }
}
