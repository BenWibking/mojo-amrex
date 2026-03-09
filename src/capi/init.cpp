#include "capi_internal.H"

extern "C" amrex_mojo_status_code_t
amrex_mojo_initialize(int32_t argc, const char* const* argv, int32_t use_parmparse)
{
    (void)argc;
    (void)argv;
    (void)use_parmparse;

    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_initialize is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t amrex_mojo_finalize(void)
{
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_finalize is not implemented yet."
    );
}

extern "C" int32_t amrex_mojo_initialized(void)
{
    amrex_mojo::detail::clear_last_error();
    return 0;
}

extern "C" int32_t amrex_mojo_parallel_nprocs(void)
{
    amrex_mojo::detail::clear_last_error();
    return 1;
}

extern "C" int32_t amrex_mojo_parallel_myproc(void)
{
    amrex_mojo::detail::clear_last_error();
    return 0;
}

extern "C" int32_t amrex_mojo_parallel_ioprocessor(void)
{
    amrex_mojo::detail::clear_last_error();
    return 1;
}

extern "C" int32_t amrex_mojo_parallel_ioprocessor_number(void)
{
    amrex_mojo::detail::clear_last_error();
    return 0;
}
