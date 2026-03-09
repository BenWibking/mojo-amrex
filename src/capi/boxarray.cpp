#include "capi_internal.H"

extern "C" amrex_mojo_boxarray_t*
amrex_mojo_boxarray_create_from_box(amrex_mojo_runtime_t* runtime, amrex_mojo_box_3d domain)
{
    if (runtime == nullptr || runtime->state == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_create_from_box requires a live runtime."
        );
        return nullptr;
    }

    auto* state = amrex_mojo::detail::retain_runtime(runtime->state);
    try {
        auto* boxarray = new amrex_mojo_boxarray{
            state,
            amrex::BoxArray(amrex_mojo::detail::to_box(domain))
        };
        amrex_mojo::detail::clear_last_error();
        return boxarray;
    } catch (const std::exception& ex) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
        return nullptr;
    } catch (...) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "boxarray_create_from_box failed with an unknown exception."
        );
        return nullptr;
    }
}

extern "C" amrex_mojo_boxarray_t*
amrex_mojo_boxarray_create_from_bounds(
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
    return amrex_mojo_boxarray_create_from_box(
        runtime,
        amrex_mojo_box_3d{
            amrex_mojo_intvect_3d{lo_x, lo_y, lo_z},
            amrex_mojo_intvect_3d{hi_x, hi_y, hi_z},
            amrex_mojo_intvect_3d{nodal_x, nodal_y, nodal_z}
        }
    );
}

extern "C" void amrex_mojo_boxarray_destroy(amrex_mojo_boxarray_t* boxarray)
{
    if (boxarray == nullptr) {
        amrex_mojo::detail::clear_last_error();
        return;
    }

    auto* state = boxarray->state;
    delete boxarray;
    amrex_mojo::detail::release_runtime(state);
    amrex_mojo::detail::clear_last_error();
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_boxarray_max_size(amrex_mojo_boxarray_t* boxarray, amrex_mojo_intvect_3d max_size)
{
    if (boxarray == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_max_size requires a non-null boxarray."
        );
    }

    try {
        boxarray->value.maxSize(amrex_mojo::detail::to_intvect(max_size));
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "boxarray_max_size failed with an unknown exception."
        );
    }
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_boxarray_max_size_xyz(amrex_mojo_boxarray_t* boxarray, int32_t x, int32_t y, int32_t z)
{
    return amrex_mojo_boxarray_max_size(boxarray, amrex_mojo_intvect_3d{x, y, z});
}

extern "C" int32_t amrex_mojo_boxarray_size(const amrex_mojo_boxarray_t* boxarray)
{
    if (boxarray == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_size requires a non-null boxarray."
        );
        return -1;
    }

    amrex_mojo::detail::clear_last_error();
    return static_cast<int32_t>(boxarray->value.size());
}

extern "C" amrex_mojo_box_3d amrex_mojo_boxarray_box(const amrex_mojo_boxarray_t* boxarray, int32_t index)
{
    if (boxarray == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_box requires a non-null boxarray."
        );
        return amrex_mojo_box_3d{};
    }

    if (index < 0 || index >= boxarray->value.size()) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_box index is out of range."
        );
        return amrex_mojo_box_3d{};
    }

    amrex_mojo::detail::clear_last_error();
    return amrex_mojo::detail::from_box(boxarray->value[index]);
}

extern "C" amrex_mojo_status_code_t amrex_mojo_boxarray_box_metadata(
    const amrex_mojo_boxarray_t* boxarray,
    int32_t index,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
)
{
    if (boxarray == nullptr || out_small_end == nullptr || out_big_end == nullptr || out_nodal == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_box_metadata requires non-null pointers."
        );
    }

    if (index < 0 || index >= boxarray->value.size()) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_box_metadata index is out of range."
        );
    }

    const auto& box = boxarray->value[index];
    const auto small_end = box.smallEnd();
    const auto big_end = box.bigEnd();
    const auto nodal = box.type();
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
