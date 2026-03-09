#include "capi_internal.H"

#include <string>

namespace
{
    void fill_box_arrays(const amrex::Box& box, int32_t* lo, int32_t* hi, int32_t* nodal)
    {
        const auto lo_vect = box.smallEnd();
        const auto hi_vect = box.bigEnd();
        const auto nodal_vect = box.type();
        lo[0] = lo_vect[0];
        lo[1] = lo_vect[1];
        lo[2] = lo_vect[2];
        hi[0] = hi_vect[0];
        hi[1] = hi_vect[1];
        hi[2] = hi_vect[2];
        if (nodal != nullptr) {
            nodal[0] = nodal_vect[0];
            nodal[1] = nodal_vect[1];
            nodal[2] = nodal_vect[2];
        }
    }

    auto require_tile(const amrex_mojo_multifab_t* multifab, int32_t tile_index)
        -> const amrex_mojo::detail::tile_descriptor*
    {
        if (multifab == nullptr || multifab->value == nullptr) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "multifab tile access requires a non-null multifab."
            );
            return nullptr;
        }

        if (tile_index < 0 || tile_index >= static_cast<int32_t>(multifab->tiles.size())) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "tile index is out of range."
            );
            return nullptr;
        }

        return &multifab->tiles[static_cast<std::size_t>(tile_index)];
    }

    auto validate_component_range(const amrex::MultiFab& multifab, int32_t start_comp, int32_t ncomp)
        -> amrex_mojo_status_code_t
    {
        if (start_comp < 0 || ncomp <= 0 || start_comp + ncomp > multifab.nComp()) {
            return amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "component range is out of bounds."
            );
        }

        return AMREX_MOJO_STATUS_OK;
    }
}

extern "C" amrex_mojo_multifab_t*
amrex_mojo_multifab_create(
    amrex_mojo_runtime_t* runtime,
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow
)
{
    if (runtime == nullptr || runtime->state == nullptr || boxarray == nullptr || distmap == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_create requires a live runtime, boxarray, and distmap."
        );
        return nullptr;
    }

    if (ncomp <= 0) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_create requires ncomp > 0."
        );
        return nullptr;
    }

    auto* state = amrex_mojo::detail::retain_runtime(runtime->state);
    try {
        auto multifab_ptr = std::make_unique<amrex::MultiFab>(
            boxarray->value,
            distmap->value,
            ncomp,
            amrex_mojo::detail::to_intvect(ngrow)
        );

        auto* multifab = new amrex_mojo_multifab{
            state,
            std::move(multifab_ptr),
            {}
        };

        for (amrex::MFIter mfi(*multifab->value, amrex::MFItInfo().EnableTiling()); mfi.isValid(); ++mfi) {
            multifab->tiles.push_back(amrex_mojo::detail::tile_descriptor{
                mfi.tilebox(),
                mfi.validbox(),
                &((*multifab->value)[mfi])
            });
        }

        amrex_mojo::detail::clear_last_error();
        return multifab;
    } catch (const std::exception& ex) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
        return nullptr;
    } catch (...) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "multifab_create failed with an unknown exception."
        );
        return nullptr;
    }
}

extern "C" amrex_mojo_multifab_t*
amrex_mojo_multifab_create_xyz(
    amrex_mojo_runtime_t* runtime,
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    int32_t ngrow_x,
    int32_t ngrow_y,
    int32_t ngrow_z
)
{
    return amrex_mojo_multifab_create(
        runtime,
        boxarray,
        distmap,
        ncomp,
        amrex_mojo_intvect_3d{ngrow_x, ngrow_y, ngrow_z}
    );
}

extern "C" void amrex_mojo_multifab_destroy(amrex_mojo_multifab_t* multifab)
{
    if (multifab == nullptr) {
        amrex_mojo::detail::clear_last_error();
        return;
    }

    auto* state = multifab->state;
    delete multifab;
    amrex_mojo::detail::release_runtime(state);
    amrex_mojo::detail::clear_last_error();
}

extern "C" int32_t amrex_mojo_multifab_ncomp(const amrex_mojo_multifab_t* multifab)
{
    if (multifab == nullptr || multifab->value == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_ncomp requires a non-null multifab."
        );
        return -1;
    }

    amrex_mojo::detail::clear_last_error();
    return multifab->value->nComp();
}

extern "C" amrex_mojo_intvect_3d amrex_mojo_multifab_ngrow(const amrex_mojo_multifab_t* multifab)
{
    if (multifab == nullptr || multifab->value == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_ngrow requires a non-null multifab."
        );
        return amrex_mojo_intvect_3d{};
    }

    amrex_mojo::detail::clear_last_error();
    return amrex_mojo::detail::from_intvect(multifab->value->nGrowVect());
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_set_val(
    amrex_mojo_multifab_t* multifab,
    double value,
    int32_t start_comp,
    int32_t ncomp
)
{
    if (multifab == nullptr || multifab->value == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_set_val requires a non-null multifab."
        );
    }

    if (validate_component_range(*multifab->value, start_comp, ncomp) != AMREX_MOJO_STATUS_OK) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    try {
        multifab->value->setVal(value, start_comp, ncomp, multifab->value->nGrowVect());
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "multifab_set_val failed with an unknown exception."
        );
    }
}

extern "C" int32_t amrex_mojo_multifab_tile_count(const amrex_mojo_multifab_t* multifab)
{
    if (multifab == nullptr || multifab->value == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_tile_count requires a non-null multifab."
        );
        return -1;
    }

    amrex_mojo::detail::clear_last_error();
    return static_cast<int32_t>(multifab->tiles.size());
}

extern "C" amrex_mojo_box_3d amrex_mojo_multifab_tile_box(const amrex_mojo_multifab_t* multifab, int32_t tile_index)
{
    const auto* tile = require_tile(multifab, tile_index);
    if (tile == nullptr) {
        return amrex_mojo_box_3d{};
    }

    amrex_mojo::detail::clear_last_error();
    return amrex_mojo::detail::from_box(tile->tile_box);
}

extern "C" amrex_mojo_box_3d amrex_mojo_multifab_valid_box(const amrex_mojo_multifab_t* multifab, int32_t tile_index)
{
    const auto* tile = require_tile(multifab, tile_index);
    if (tile == nullptr) {
        return amrex_mojo_box_3d{};
    }

    amrex_mojo::detail::clear_last_error();
    return amrex_mojo::detail::from_box(tile->valid_box);
}

extern "C" amrex_mojo_array4_view_f64
amrex_mojo_multifab_array4(const amrex_mojo_multifab_t* multifab, int32_t tile_index)
{
    const auto* tile = require_tile(multifab, tile_index);
    if (tile == nullptr) {
        return amrex_mojo_array4_view_f64{};
    }

    const auto array = tile->fab->array();
    amrex_mojo_array4_view_f64 view{};
    view.data = array.dataPtr();
    view.lo_x = array.begin[0];
    view.lo_y = array.begin[1];
    view.lo_z = array.begin[2];
    view.hi_x = array.end[0] - 1;
    view.hi_y = array.end[1] - 1;
    view.hi_z = array.end[2] - 1;
    view.stride_i = 1;
    view.stride_j = array.get_stride<1>();
    view.stride_k = array.get_stride<2>();
    view.stride_n = array.get_stride<3>();
    view.ncomp = array.nComp();
    amrex_mojo::detail::clear_last_error();
    return view;
}

extern "C" double* amrex_mojo_multifab_data_ptr(const amrex_mojo_multifab_t* multifab, int32_t tile_index)
{
    const auto* tile = require_tile(multifab, tile_index);
    if (tile == nullptr) {
        return nullptr;
    }

    amrex_mojo::detail::clear_last_error();
    return tile->fab->dataPtr();
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_tile_metadata(
    const amrex_mojo_multifab_t* multifab,
    int32_t tile_index,
    int32_t* tile_lo,
    int32_t* tile_hi,
    int32_t* valid_lo,
    int32_t* valid_hi,
    int32_t* data_lo,
    int32_t* data_hi,
    int64_t* stride,
    int32_t* out_ncomp
)
{
    if (tile_lo == nullptr || tile_hi == nullptr || valid_lo == nullptr || valid_hi == nullptr ||
        data_lo == nullptr || data_hi == nullptr || stride == nullptr || out_ncomp == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_tile_metadata requires non-null output pointers."
        );
    }

    const auto* tile = require_tile(multifab, tile_index);
    if (tile == nullptr) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    const auto array = tile->fab->array();
    fill_box_arrays(tile->tile_box, tile_lo, tile_hi, nullptr);
    fill_box_arrays(tile->valid_box, valid_lo, valid_hi, nullptr);
    data_lo[0] = array.begin[0];
    data_lo[1] = array.begin[1];
    data_lo[2] = array.begin[2];
    data_hi[0] = array.end[0] - 1;
    data_hi[1] = array.end[1] - 1;
    data_hi[2] = array.end[2] - 1;
    stride[0] = 1;
    stride[1] = array.get_stride<1>();
    stride[2] = array.get_stride<2>();
    stride[3] = array.get_stride<3>();
    *out_ncomp = array.nComp();

    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" double amrex_mojo_multifab_min(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (multifab == nullptr || multifab->value == nullptr || comp < 0 || comp >= multifab->value->nComp()) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_min requires a valid multifab and component index."
        );
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    return multifab->value->min(comp, 0);
}

extern "C" double amrex_mojo_multifab_max(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (multifab == nullptr || multifab->value == nullptr || comp < 0 || comp >= multifab->value->nComp()) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_max requires a valid multifab and component index."
        );
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    return multifab->value->max(comp, 0);
}

extern "C" double amrex_mojo_multifab_sum(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (multifab == nullptr || multifab->value == nullptr || comp < 0 || comp >= multifab->value->nComp()) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_sum requires a valid multifab and component index."
        );
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    return multifab->value->sum(comp);
}

extern "C" double amrex_mojo_multifab_norm0(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (multifab == nullptr || multifab->value == nullptr || comp < 0 || comp >= multifab->value->nComp()) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_norm0 requires a valid multifab and component index."
        );
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    return multifab->value->norm0(comp);
}

extern "C" double amrex_mojo_multifab_norm1(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (multifab == nullptr || multifab->value == nullptr || comp < 0 || comp >= multifab->value->nComp()) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_norm1 requires a valid multifab and component index."
        );
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    return multifab->value->norm1(comp);
}

extern "C" double amrex_mojo_multifab_norm2(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (multifab == nullptr || multifab->value == nullptr || comp < 0 || comp >= multifab->value->nComp()) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_norm2 requires a valid multifab and component index."
        );
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    return multifab->value->norm2(comp);
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_plus(
    amrex_mojo_multifab_t* multifab,
    double value,
    int32_t start_comp,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow
)
{
    if (multifab == nullptr || multifab->value == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_plus requires a non-null multifab."
        );
    }

    if (validate_component_range(*multifab->value, start_comp, ncomp) != AMREX_MOJO_STATUS_OK) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    const auto scalar_ngrow = amrex_mojo::detail::to_scalar_ngrow(ngrow);
    if (scalar_ngrow < 0) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_plus currently requires isotropic ghost widths."
        );
    }

    try {
        multifab->value->plus(value, start_comp, ncomp, scalar_ngrow);
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "multifab_plus failed with an unknown exception."
        );
    }
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_mult(
    amrex_mojo_multifab_t* multifab,
    double value,
    int32_t start_comp,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow
)
{
    if (multifab == nullptr || multifab->value == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_mult requires a non-null multifab."
        );
    }

    if (validate_component_range(*multifab->value, start_comp, ncomp) != AMREX_MOJO_STATUS_OK) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    const auto scalar_ngrow = amrex_mojo::detail::to_scalar_ngrow(ngrow);
    if (scalar_ngrow < 0) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_mult currently requires isotropic ghost widths."
        );
    }

    try {
        multifab->value->mult(value, start_comp, ncomp, scalar_ngrow);
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "multifab_mult failed with an unknown exception."
        );
    }
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_copy(
    amrex_mojo_multifab_t* dst_multifab,
    const amrex_mojo_multifab_t* src_multifab,
    int32_t src_comp,
    int32_t dst_comp,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow
)
{
    if (dst_multifab == nullptr || dst_multifab->value == nullptr || src_multifab == nullptr ||
        src_multifab->value == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_copy requires non-null source and destination multifabs."
        );
    }

    if (validate_component_range(*src_multifab->value, src_comp, ncomp) != AMREX_MOJO_STATUS_OK ||
        validate_component_range(*dst_multifab->value, dst_comp, ncomp) != AMREX_MOJO_STATUS_OK) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    try {
        amrex::MultiFab::Copy(
            *dst_multifab->value,
            *src_multifab->value,
            src_comp,
            dst_comp,
            ncomp,
            amrex_mojo::detail::to_intvect(ngrow)
        );
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "multifab_copy failed with an unknown exception."
        );
    }
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_write_single_level_plotfile(
    const amrex_mojo_multifab_t* multifab,
    const amrex_mojo_geometry_t* geometry,
    const char* plotfile,
    double time,
    int32_t level_step
)
{
    if (multifab == nullptr || multifab->value == nullptr || geometry == nullptr || plotfile == nullptr ||
        std::string(plotfile).empty()) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "write_single_level_plotfile requires non-null multifab, geometry, and plotfile path."
        );
    }

    try {
        amrex::Vector<std::string> varnames;
        varnames.reserve(multifab->value->nComp());
        for (int comp = 0; comp < multifab->value->nComp(); ++comp) {
            varnames.push_back("Var" + std::to_string(comp));
        }

        amrex::WriteSingleLevelPlotfile(
            std::string(plotfile),
            *multifab->value,
            varnames,
            geometry->value,
            time,
            level_step
        );
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "write_single_level_plotfile failed with an unknown exception."
        );
    }
}
