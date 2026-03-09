#pragma once

#include "amrex_mojo_capi.h"

#include <string>

namespace amrex_mojo::detail
{
    void clear_last_error() noexcept;

    amrex_mojo_status_code_t
    set_last_error(amrex_mojo_status_code_t code, const char* message) noexcept;

    amrex_mojo_status_code_t
    set_last_error(amrex_mojo_status_code_t code, const std::string& message) noexcept;
}
