#include "capi_internal.H"

extern "C" amrex_mojo_geometry_t*
amrex_mojo_geometry_create(amrex_mojo_runtime_t* runtime, amrex_mojo_box_3d domain)
{
    return amrex_mojo_geometry_create_with_real_box_and_periodicity(
        runtime,
        domain,
        amrex_mojo::detail::from_realbox(amrex_mojo::detail::unit_realbox()),
        amrex_mojo_intvect_3d{0, 0, 0}
    );
}

extern "C" amrex_mojo_geometry_t* amrex_mojo_geometry_create_with_real_box_and_periodicity(
    amrex_mojo_runtime_t* runtime,
    amrex_mojo_box_3d domain,
    amrex_mojo_realbox_3d real_box,
    amrex_mojo_intvect_3d is_periodic
)
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
                amrex_mojo::detail::to_realbox(real_box),
                0,
                amrex_mojo::detail::to_periodicity(is_periodic)
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

extern "C" amrex_mojo_geometry_t*
amrex_mojo_geometry_create_from_bounds_with_real_box_and_periodicity(
    amrex_mojo_runtime_t* runtime,
    int32_t lo_x,
    int32_t lo_y,
    int32_t lo_z,
    int32_t hi_x,
    int32_t hi_y,
    int32_t hi_z,
    int32_t nodal_x,
    int32_t nodal_y,
    int32_t nodal_z,
    double real_lo_x,
    double real_lo_y,
    double real_lo_z,
    double real_hi_x,
    double real_hi_y,
    double real_hi_z,
    int32_t periodic_x,
    int32_t periodic_y,
    int32_t periodic_z
)
{
    return amrex_mojo_geometry_create_with_real_box_and_periodicity(
        runtime,
        amrex_mojo_box_3d{
            amrex_mojo_intvect_3d{lo_x, lo_y, lo_z},
            amrex_mojo_intvect_3d{hi_x, hi_y, hi_z},
            amrex_mojo_intvect_3d{nodal_x, nodal_y, nodal_z}
        },
        amrex_mojo_realbox_3d{
            real_lo_x,
            real_lo_y,
            real_lo_z,
            real_hi_x,
            real_hi_y,
            real_hi_z
        },
        amrex_mojo_intvect_3d{periodic_x, periodic_y, periodic_z}
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

extern "C" amrex_mojo_status_code_t amrex_mojo_geometry_domain_metadata(
    const amrex_mojo_geometry_t* geometry,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
)
{
    if (geometry == nullptr || out_small_end == nullptr || out_big_end == nullptr || out_nodal == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_domain_metadata requires non-null pointers."
        );
    }

    const auto domain = geometry->value.Domain();
    const auto small_end = domain.smallEnd();
    const auto big_end = domain.bigEnd();
    const auto nodal = domain.type();
    out_small_end[0] = small_end[0];
    out_small_end[1] = small_end[1];
    out_small_end[2] = small_end[2];
    out_big_end[0] = big_end[0];
    out_big_end[1] = big_end[1];
    out_big_end[2] = big_end[2];
    out_nodal[0] = nodal[0];
    out_nodal[1] = nodal[1];
    out_nodal[2] = nodal[2];
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t amrex_mojo_geometry_prob_domain_metadata(
    const amrex_mojo_geometry_t* geometry,
    double* out_lo,
    double* out_hi
)
{
    if (geometry == nullptr || out_lo == nullptr || out_hi == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_prob_domain_metadata requires non-null pointers."
        );
    }

    const auto prob_domain = geometry->value.ProbDomain();
    out_lo[0] = prob_domain.lo(0);
    out_lo[1] = prob_domain.lo(1);
    out_lo[2] = prob_domain.lo(2);
    out_hi[0] = prob_domain.hi(0);
    out_hi[1] = prob_domain.hi(1);
    out_hi[2] = prob_domain.hi(2);
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_geometry_cell_size_data(const amrex_mojo_geometry_t* geometry, double* out_cell_size)
{
    if (geometry == nullptr || out_cell_size == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_cell_size_data requires non-null pointers."
        );
    }

    out_cell_size[0] = geometry->value.CellSize(0);
    out_cell_size[1] = geometry->value.CellSize(1);
    out_cell_size[2] = geometry->value.CellSize(2);
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_geometry_periodicity_data(const amrex_mojo_geometry_t* geometry, int32_t* out_periodicity)
{
    if (geometry == nullptr || out_periodicity == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "geometry_periodicity_data requires non-null pointers."
        );
    }

    out_periodicity[0] = geometry->value.isPeriodic(0);
    out_periodicity[1] = geometry->value.isPeriodic(1);
    out_periodicity[2] = geometry->value.isPeriodic(2);
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}
