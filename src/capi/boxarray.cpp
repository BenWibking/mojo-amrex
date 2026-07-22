#include "capi_internal.H"

namespace
{
    auto is_valid_index_type(amrex_mojo_intvect_3d typ) -> bool
    {
        return (typ.x == 0 || typ.x == 1) &&
            (typ.y == 0 || typ.y == 1) &&
            (typ.z == 0 || typ.z == 1);
    }
}

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

extern "C" amrex_mojo_status_code_t
amrex_mojo_boxarray_convert_xyz(amrex_mojo_boxarray_t* boxarray, int32_t x, int32_t y, int32_t z)
{
    return amrex_mojo_boxarray_convert(boxarray, amrex_mojo_intvect_3d{x, y, z});
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_boxarray_surrounding_nodes(amrex_mojo_boxarray_t* boxarray, int32_t dir)
{
    if (boxarray == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_surrounding_nodes requires a non-null boxarray."
        );
    }

    if (dir < 0 || dir >= AMREX_SPACEDIM) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_surrounding_nodes requires a valid direction."
        );
    }

    try {
        boxarray->value.surroundingNodes(dir);
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "boxarray_surrounding_nodes failed with an unknown exception."
        );
    }
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_boxarray_surrounding_nodes_all(amrex_mojo_boxarray_t* boxarray)
{
    if (boxarray == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_surrounding_nodes_all requires a non-null boxarray."
        );
    }

    try {
        boxarray->value.surroundingNodes();
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "boxarray_surrounding_nodes_all failed with an unknown exception."
        );
    }
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_boxarray_convert(amrex_mojo_boxarray_t* boxarray, amrex_mojo_intvect_3d typ)
{
    if (boxarray == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_convert requires a non-null boxarray."
        );
    }

    if (!is_valid_index_type(typ)) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_convert requires each index type entry to be 0 or 1."
        );
    }

    try {
        boxarray->value.convert(amrex_mojo::detail::to_intvect(typ));
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "boxarray_convert failed with an unknown exception."
        );
    }
}

extern "C" amrex_mojo_boxarray_t*
amrex_mojo_boxarray_convert_copy(
    const amrex_mojo_boxarray_t* boxarray,
    amrex_mojo_intvect_3d typ
)
{
    if (boxarray == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_convert_copy requires a non-null boxarray."
        );
        return nullptr;
    }

    if (!is_valid_index_type(typ)) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_convert_copy requires each index type entry to be 0 or 1."
        );
        return nullptr;
    }

    auto* state = amrex_mojo::detail::retain_runtime(boxarray->state);
    try {
        auto* converted = new amrex_mojo_boxarray{
            state,
            amrex::convert(boxarray->value, amrex_mojo::detail::to_intvect(typ))
        };
        amrex_mojo::detail::clear_last_error();
        return converted;
    } catch (const std::exception& ex) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
        return nullptr;
    } catch (...) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "boxarray_convert_copy failed with an unknown exception."
        );
        return nullptr;
    }
}

extern "C" amrex_mojo_boxarray_t*
amrex_mojo_boxarray_convert_copy_xyz(
    const amrex_mojo_boxarray_t* boxarray,
    int32_t x,
    int32_t y,
    int32_t z
)
{
    return amrex_mojo_boxarray_convert_copy(boxarray, amrex_mojo_intvect_3d{x, y, z});
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

extern "C" amrex_mojo_status_code_t amrex_mojo_boxarray_box_into(
    const amrex_mojo_boxarray_t* boxarray,
    int32_t index,
    amrex_mojo_box_3d* out_box
)
{
    if (out_box == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "boxarray_box_into requires a non-null output pointer."
        );
    }
    if (boxarray == nullptr || index < 0 || index >= boxarray->value.size()) {
        (void)amrex_mojo_boxarray_box(boxarray, index);
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    *out_box = amrex_mojo_boxarray_box(boxarray, index);
    return AMREX_MOJO_STATUS_OK;
}
