#include "capi_internal.H"

extern "C" amrex_mojo_status_code_t
amrex_mojo_geometry_create(
    const amrex_mojo_box_3d* domain,
    amrex_mojo_geometry_t** out_geometry
)
{
    if (domain == nullptr || out_geometry == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_create requires non-null pointers."
        );
    }

    *out_geometry = nullptr;
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "amrex_mojo_geometry_create is not implemented yet."
    );
}

extern "C" amrex_mojo_status_code_t amrex_mojo_geometry_destroy(amrex_mojo_geometry_t* geometry)
{
    (void)geometry;
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}
