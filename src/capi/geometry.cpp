#include "capi_internal.H"

extern "C" amrex_mojo_geometry_t*
amrex_mojo_geometry_create(amrex_mojo_runtime_t* runtime, amrex_mojo_box_3d domain)
{
    if (runtime == nullptr || runtime->state == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_create requires a live runtime."
        );
        return nullptr;
    }

    auto* state = amrex_mojo::detail::retain_runtime(runtime->state);
    try {
        auto* geometry = new amrex_mojo_geometry{
            state,
            amrex::Geometry(
                amrex_mojo::detail::to_box(domain),
                amrex_mojo::detail::unit_realbox(),
                0,
                {AMREX_D_DECL(0, 0, 0)}
            )
        };
        amrex_mojo::detail::clear_last_error();
        return geometry;
    } catch (const std::exception& ex) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
        return nullptr;
    } catch (...) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "geometry_create failed with an unknown exception."
        );
        return nullptr;
    }
}

extern "C" amrex_mojo_geometry_t*
amrex_mojo_geometry_create_from_bounds(
    amrex_mojo_runtime_t* runtime,
    int32_t lo_x,
    int32_t lo_y,
    int32_t lo_z,
    int32_t hi_x,
    int32_t hi_y,
    int32_t hi_z,
    int32_t nodal_x,
    int32_t nodal_y,
    int32_t nodal_z
)
{
    return amrex_mojo_geometry_create(
        runtime,
        amrex_mojo_box_3d{
            amrex_mojo_intvect_3d{lo_x, lo_y, lo_z},
            amrex_mojo_intvect_3d{hi_x, hi_y, hi_z},
            amrex_mojo_intvect_3d{nodal_x, nodal_y, nodal_z}
        }
    );
}

extern "C" void amrex_mojo_geometry_destroy(amrex_mojo_geometry_t* geometry)
{
    if (geometry == nullptr) {
        amrex_mojo::detail::clear_last_error();
        return;
    }

    auto* state = geometry->state;
    delete geometry;
    amrex_mojo::detail::release_runtime(state);
    amrex_mojo::detail::clear_last_error();
}

extern "C" amrex_mojo_box_3d amrex_mojo_geometry_domain(const amrex_mojo_geometry_t* geometry)
{
    if (geometry == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_domain requires a non-null geometry."
        );
        return amrex_mojo_box_3d{};
    }

    amrex_mojo::detail::clear_last_error();
    return amrex_mojo::detail::from_box(geometry->value.Domain());
}

extern "C" amrex_mojo_realbox_3d amrex_mojo_geometry_prob_domain(const amrex_mojo_geometry_t* geometry)
{
    if (geometry == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_prob_domain requires a non-null geometry."
        );
        return amrex_mojo_realbox_3d{};
    }

    amrex_mojo::detail::clear_last_error();
    return amrex_mojo::detail::from_realbox(geometry->value.ProbDomain());
}

extern "C" amrex_mojo_realvect_3d amrex_mojo_geometry_cell_size(const amrex_mojo_geometry_t* geometry)
{
    if (geometry == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_cell_size requires a non-null geometry."
        );
        return amrex_mojo_realvect_3d{};
    }

    amrex_mojo::detail::clear_last_error();
    return amrex_mojo::detail::from_cell_size(geometry->value);
}

extern "C" amrex_mojo_intvect_3d amrex_mojo_geometry_periodicity(const amrex_mojo_geometry_t* geometry)
{
    if (geometry == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_periodicity requires a non-null geometry."
        );
        return amrex_mojo_intvect_3d{};
    }

    amrex_mojo::detail::clear_last_error();
    return amrex_mojo_intvect_3d{
        geometry->value.isPeriodic(0),
        geometry->value.isPeriodic(1),
        geometry->value.isPeriodic(2)
    };
}
