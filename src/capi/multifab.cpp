#include "capi_internal.H"

#include <cmath>
#include <limits>
#include <string>
#include <type_traits>

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

    auto multifab_has_value(const amrex_mojo_multifab_t* multifab) -> bool
    {
        if (multifab == nullptr) {
            return false;
        }

        return std::visit([](const auto& ptr) { return static_cast<bool>(ptr); }, multifab->value);
    }

    auto require_live_multifab(
        const amrex_mojo_multifab_t* multifab,
        const char* context
    ) -> bool
    {
        if (!multifab_has_value(multifab)) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                std::string(context) + " requires a non-null multifab."
            );
            return false;
        }

        return true;
    }

    template <typename Fn>
    decltype(auto) visit_multifab(const amrex_mojo_multifab_t* multifab, Fn&& fn)
    {
        return std::visit(
            [&](const auto& ptr) -> decltype(auto) { return fn(*ptr); },
            multifab->value
        );
    }

    template <typename Fn>
    decltype(auto) visit_multifab(amrex_mojo_multifab_t* multifab, Fn&& fn)
    {
        return std::visit(
            [&](auto& ptr) -> decltype(auto) { return fn(*ptr); },
            multifab->value
        );
    }

    template <typename Fn>
    decltype(auto) visit_multifab_pair(
        amrex_mojo_multifab_t* dst_multifab,
        const amrex_mojo_multifab_t* src_multifab,
        Fn&& fn
    )
    {
        return std::visit(
            [&](auto& dst_ptr, const auto& src_ptr) -> decltype(auto) {
                return fn(*dst_ptr, *src_ptr);
            },
            dst_multifab->value,
            src_multifab->value
        );
    }

    auto require_tile(const amrex_mojo_multifab_t* multifab, int32_t tile_index)
        -> const amrex_mojo::detail::tile_descriptor*
    {
        if (!require_live_multifab(multifab, "multifab tile access")) {
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

    auto require_current_mfiter_tile(const amrex_mojo_mfiter_t* mfiter)
        -> const amrex_mojo::detail::tile_descriptor*
    {
        if (mfiter == nullptr) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "mfiter access requires a non-null iterator."
            );
            return nullptr;
        }

        if (mfiter->current_tile < 0 ||
            mfiter->current_tile >= static_cast<int32_t>(mfiter->tiles.size())) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "mfiter is not positioned on a valid tile."
            );
            return nullptr;
        }

        return &mfiter->tiles[static_cast<std::size_t>(mfiter->current_tile)];
    }

    auto require_multifab_tile_for_mfiter(
        const amrex_mojo_multifab_t* multifab,
        const amrex_mojo_mfiter_t* mfiter
    ) -> const amrex_mojo::detail::tile_descriptor*
    {
        const auto* iter_tile = require_current_mfiter_tile(mfiter);
        if (iter_tile == nullptr) {
            return nullptr;
        }

        if (!require_live_multifab(multifab, "multifab access by MFIter")) {
            return nullptr;
        }

        if (mfiter->current_tile >= static_cast<int32_t>(multifab->tiles.size())) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "multifab is not compatible with the iterator tile ordering."
            );
            return nullptr;
        }

        const auto& multifab_tile =
            multifab->tiles[static_cast<std::size_t>(mfiter->current_tile)];
        if (multifab_tile.tile_box != iter_tile->tile_box ||
            multifab_tile.valid_box != iter_tile->valid_box) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "multifab tile layout is not compatible with the iterator."
            );
            return nullptr;
        }

        return &multifab_tile;
    }

    template <typename MultifabT>
    auto validate_component_range(const MultifabT& multifab, int32_t start_comp, int32_t ncomp)
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

    auto arena_for_memory_kind(amrex_mojo_multifab_memory_kind_t memory_kind) -> amrex::Arena*
    {
        switch (memory_kind) {
        case AMREX_MOJO_MULTIFAB_MEMORY_DEFAULT: return nullptr;
        default: return nullptr;
        }
    }

    auto is_valid_memory_kind(amrex_mojo_multifab_memory_kind_t memory_kind) -> bool
    {
        switch (memory_kind) {
        case AMREX_MOJO_MULTIFAB_MEMORY_DEFAULT: return true;
        default: return false;
        }
    }

    auto mfinfo_for_memory_kind(amrex_mojo_multifab_memory_kind_t memory_kind) -> amrex::MFInfo
    {
        auto info = amrex::MFInfo{};
        if (auto* arena = arena_for_memory_kind(memory_kind); arena != nullptr) {
            info.SetArena(arena);
        }
        return info;
    }

    auto is_valid_datatype(amrex_mojo_datatype_t datatype) -> bool
    {
        switch (datatype) {
        case AMREX_MOJO_DATATYPE_FLOAT64:
        case AMREX_MOJO_DATATYPE_FLOAT32: return true;
        default: return false;
        }
    }

    template <typename MultifabT>
    auto populate_tiles(MultifabT& multifab) -> std::vector<amrex_mojo::detail::tile_descriptor>
    {
        std::vector<amrex_mojo::detail::tile_descriptor> tiles;
        for (amrex::MFIter mfi(multifab, amrex::MFItInfo().EnableTiling()); mfi.isValid(); ++mfi) {
            tiles.push_back(amrex_mojo::detail::tile_descriptor{
                mfi.tilebox(),
                mfi.validbox(),
                multifab[mfi].box(),
                mfi.index(),
                mfi.LocalTileIndex(),
                &(multifab[mfi])
            });
        }
        return tiles;
    }

    template <typename FabT>
    auto require_host_accessible_typed(
        const amrex_mojo::detail::tile_descriptor* tile,
        const char* context
    ) -> amrex_mojo_status_code_t
    {
        if (tile == nullptr || tile->fab == nullptr) {
            return amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INTERNAL_ERROR,
                std::string(context) + " could not resolve backing tile storage."
            );
        }

        auto* fab = static_cast<FabT*>(tile->fab);
        const auto* arena = fab->arena();
        if (arena != nullptr && !arena->isHostAccessible()) {
            return amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                std::string(context) + " requires host-accessible storage."
            );
        }

        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    }

    auto require_host_accessible(
        const amrex_mojo_multifab_t* multifab,
        const amrex_mojo::detail::tile_descriptor* tile,
        const char* context
    ) -> amrex_mojo_status_code_t
    {
        switch (multifab->datatype) {
        case AMREX_MOJO_DATATYPE_FLOAT64:
            return require_host_accessible_typed<amrex::FArrayBox>(tile, context);
        case AMREX_MOJO_DATATYPE_FLOAT32:
            return require_host_accessible_typed<amrex::BaseFab<float>>(tile, context);
        default:
            return amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                std::string(context) + " received an unknown multifab datatype."
            );
        }
    }

    template <typename FabT>
    auto require_device_accessible_typed(
        const amrex_mojo::detail::tile_descriptor* tile,
        const char* context
    ) -> amrex_mojo_status_code_t
    {
        if (tile == nullptr || tile->fab == nullptr) {
            return amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INTERNAL_ERROR,
                std::string(context) + " could not resolve backing tile storage."
            );
        }

        auto* fab = static_cast<FabT*>(tile->fab);
        const auto* arena = fab->arena();
        if (arena == nullptr || !arena->isDeviceAccessible()) {
            return amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                std::string(context) + " requires device-accessible storage."
            );
        }

        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    }

    auto require_device_accessible(
        const amrex_mojo_multifab_t* multifab,
        const amrex_mojo::detail::tile_descriptor* tile,
        const char* context
    ) -> amrex_mojo_status_code_t
    {
        switch (multifab->datatype) {
        case AMREX_MOJO_DATATYPE_FLOAT64:
            return require_device_accessible_typed<amrex::FArrayBox>(tile, context);
        case AMREX_MOJO_DATATYPE_FLOAT32:
            return require_device_accessible_typed<amrex::BaseFab<float>>(tile, context);
        default:
            return amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                std::string(context) + " received an unknown multifab datatype."
            );
        }
    }

    template <typename FabT>
    void fill_array4_metadata_from_fab(
        FabT* fab,
        int32_t* data_lo,
        int32_t* data_hi,
        int64_t* stride,
        int32_t* out_ncomp
    )
    {
        const auto array = fab->array();
        data_lo[0] = array.begin[0];
        data_lo[1] = array.begin[1];
        data_lo[2] = array.begin[2];
        data_hi[0] = array.end[0] - 1;
        data_hi[1] = array.end[1] - 1;
        data_hi[2] = array.end[2] - 1;
        stride[0] = 1;
        stride[1] = array.template get_stride<1>();
        stride[2] = array.template get_stride<2>();
        stride[3] = array.template get_stride<3>();
        *out_ncomp = array.nComp();
    }

    auto fill_array4_metadata_from_tile(
        const amrex_mojo_multifab_t* multifab,
        const amrex_mojo::detail::tile_descriptor* tile,
        int32_t* data_lo,
        int32_t* data_hi,
        int64_t* stride,
        int32_t* out_ncomp
    ) -> amrex_mojo_status_code_t
    {
        if (tile == nullptr || tile->fab == nullptr) {
            return amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INTERNAL_ERROR,
                "multifab metadata access could not resolve backing tile storage."
            );
        }

        switch (multifab->datatype) {
        case AMREX_MOJO_DATATYPE_FLOAT64:
            fill_array4_metadata_from_fab(
                static_cast<amrex::FArrayBox*>(tile->fab),
                data_lo,
                data_hi,
                stride,
                out_ncomp
            );
            break;
        case AMREX_MOJO_DATATYPE_FLOAT32:
            fill_array4_metadata_from_fab(
                static_cast<amrex::BaseFab<float>*>(tile->fab),
                data_lo,
                data_hi,
                stride,
                out_ncomp
            );
            break;
        default:
            return amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "multifab metadata access received an unknown datatype."
            );
        }

        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    }

    template <typename FabT>
    auto data_ptr_from_tile_typed(const amrex_mojo::detail::tile_descriptor* tile)
    {
        return static_cast<FabT*>(tile->fab)->dataPtr();
    }

    auto require_valid_component(
        const amrex_mojo_multifab_t* multifab,
        int32_t comp,
        const char* context
    ) -> bool
    {
        if (!require_live_multifab(multifab, context)) {
            return false;
        }

        const auto ncomp = visit_multifab(multifab, [](const auto& value) { return value.nComp(); });
        if (comp < 0 || comp >= ncomp) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                std::string(context) + " requires a valid component index."
            );
            return false;
        }

        return true;
    }

    auto reduce_min_f32(const amrex::fMultiFab& multifab, int32_t comp) -> double
    {
        const auto local_min = amrex::ReduceMin(
            multifab,
            0,
            [=] AMREX_GPU_HOST_DEVICE (
                amrex::Box const& bx,
                amrex::Array4<float const> const& fab
            ) noexcept -> float {
                float value = std::numeric_limits<float>::max();
                const auto lo = amrex::lbound(bx);
                const auto hi = amrex::ubound(bx);
                for (int k = lo.z; k <= hi.z; ++k) {
                    for (int j = lo.y; j <= hi.y; ++j) {
                        for (int i = lo.x; i <= hi.x; ++i) {
                            value = std::min(value, fab(i, j, k, comp));
                        }
                    }
                }
                return value;
            }
        );
        double result = local_min;
        amrex::ParallelDescriptor::ReduceRealMin(result);
        return result;
    }

    auto reduce_max_f32(const amrex::fMultiFab& multifab, int32_t comp) -> double
    {
        const auto local_max = amrex::ReduceMax(
            multifab,
            0,
            [=] AMREX_GPU_HOST_DEVICE (
                amrex::Box const& bx,
                amrex::Array4<float const> const& fab
            ) noexcept -> float {
                float value = std::numeric_limits<float>::lowest();
                const auto lo = amrex::lbound(bx);
                const auto hi = amrex::ubound(bx);
                for (int k = lo.z; k <= hi.z; ++k) {
                    for (int j = lo.y; j <= hi.y; ++j) {
                        for (int i = lo.x; i <= hi.x; ++i) {
                            value = std::max(value, fab(i, j, k, comp));
                        }
                    }
                }
                return value;
            }
        );
        double result = local_max;
        amrex::ParallelDescriptor::ReduceRealMax(result);
        return result;
    }

    auto reduce_sum_f32(const amrex::fMultiFab& multifab, int32_t comp) -> double
    {
        const auto local_sum = amrex::ReduceSum(
            multifab,
            0,
            [=] AMREX_GPU_HOST_DEVICE (
                amrex::Box const& bx,
                amrex::Array4<float const> const& fab
            ) noexcept -> float {
                float value = 0.0f;
                const auto lo = amrex::lbound(bx);
                const auto hi = amrex::ubound(bx);
                for (int k = lo.z; k <= hi.z; ++k) {
                    for (int j = lo.y; j <= hi.y; ++j) {
                        for (int i = lo.x; i <= hi.x; ++i) {
                            value += fab(i, j, k, comp);
                        }
                    }
                }
                return value;
            }
        );
        double result = local_sum;
        amrex::ParallelDescriptor::ReduceRealSum(result);
        return result;
    }

    auto reduce_norm0_f32(const amrex::fMultiFab& multifab, int32_t comp) -> double
    {
        const auto local_norm = amrex::ReduceMax(
            multifab,
            0,
            [=] AMREX_GPU_HOST_DEVICE (
                amrex::Box const& bx,
                amrex::Array4<float const> const& fab
            ) noexcept -> float {
                float value = 0.0f;
                const auto lo = amrex::lbound(bx);
                const auto hi = amrex::ubound(bx);
                for (int k = lo.z; k <= hi.z; ++k) {
                    for (int j = lo.y; j <= hi.y; ++j) {
                        for (int i = lo.x; i <= hi.x; ++i) {
                            value = std::max(value, std::abs(fab(i, j, k, comp)));
                        }
                    }
                }
                return value;
            }
        );
        double result = local_norm;
        amrex::ParallelDescriptor::ReduceRealMax(result);
        return result;
    }

    auto reduce_norm1_f32(const amrex::fMultiFab& multifab, int32_t comp) -> double
    {
        const auto local_norm = amrex::ReduceSum(
            multifab,
            0,
            [=] AMREX_GPU_HOST_DEVICE (
                amrex::Box const& bx,
                amrex::Array4<float const> const& fab
            ) noexcept -> float {
                float value = 0.0f;
                const auto lo = amrex::lbound(bx);
                const auto hi = amrex::ubound(bx);
                for (int k = lo.z; k <= hi.z; ++k) {
                    for (int j = lo.y; j <= hi.y; ++j) {
                        for (int i = lo.x; i <= hi.x; ++i) {
                            value += std::abs(fab(i, j, k, comp));
                        }
                    }
                }
                return value;
            }
        );
        double result = local_norm;
        amrex::ParallelDescriptor::ReduceRealSum(result);
        return result;
    }

    auto reduce_norm2_f32(const amrex::fMultiFab& multifab, int32_t comp) -> double
    {
        const auto local_sum_sq = amrex::ReduceSum(
            multifab,
            0,
            [=] AMREX_GPU_HOST_DEVICE (
                amrex::Box const& bx,
                amrex::Array4<float const> const& fab
            ) noexcept -> float {
                float value = 0.0f;
                const auto lo = amrex::lbound(bx);
                const auto hi = amrex::ubound(bx);
                for (int k = lo.z; k <= hi.z; ++k) {
                    for (int j = lo.y; j <= hi.y; ++j) {
                        for (int i = lo.x; i <= hi.x; ++i) {
                            const float cell = fab(i, j, k, comp);
                            value += cell * cell;
                        }
                    }
                }
                return value;
            }
        );
        double result = local_sum_sq;
        amrex::ParallelDescriptor::ReduceRealSum(result);
        return std::sqrt(result);
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
    return amrex_mojo_multifab_create_with_memory(
        runtime,
        boxarray,
        distmap,
        ncomp,
        ngrow,
        AMREX_MOJO_MULTIFAB_MEMORY_DEFAULT
    );
}

extern "C" amrex_mojo_multifab_t*
amrex_mojo_multifab_create_with_memory(
    amrex_mojo_runtime_t* runtime,
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow,
    amrex_mojo_multifab_memory_kind_t memory_kind
)
{
    return amrex_mojo_multifab_create_with_memory_and_datatype(
        runtime,
        boxarray,
        distmap,
        ncomp,
        ngrow,
        memory_kind,
        AMREX_MOJO_DATATYPE_FLOAT64
    );
}

extern "C" amrex_mojo_multifab_t*
amrex_mojo_multifab_create_with_memory_and_datatype(
    amrex_mojo_runtime_t* runtime,
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow,
    amrex_mojo_multifab_memory_kind_t memory_kind,
    amrex_mojo_datatype_t datatype
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

    if (!is_valid_memory_kind(memory_kind)) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_create received an unknown memory kind."
        );
        return nullptr;
    }

    if (!is_valid_datatype(datatype)) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_create received an unknown datatype."
        );
        return nullptr;
    }

    auto* state = amrex_mojo::detail::retain_runtime(runtime->state);
    try {
        amrex_mojo::detail::multifab_storage_t multifab_ptr;
        std::vector<amrex_mojo::detail::tile_descriptor> tiles;

        switch (datatype) {
        case AMREX_MOJO_DATATYPE_FLOAT64: {
            auto value = std::make_unique<amrex::MultiFab>(
                boxarray->value,
                distmap->value,
                ncomp,
                amrex_mojo::detail::to_intvect(ngrow),
                mfinfo_for_memory_kind(memory_kind)
            );
            tiles = populate_tiles(*value);
            multifab_ptr = std::move(value);
            break;
        }
        case AMREX_MOJO_DATATYPE_FLOAT32: {
            auto value = std::make_unique<amrex::fMultiFab>(
                boxarray->value,
                distmap->value,
                ncomp,
                amrex_mojo::detail::to_intvect(ngrow),
                mfinfo_for_memory_kind(memory_kind)
            );
            tiles = populate_tiles(*value);
            multifab_ptr = std::move(value);
            break;
        }
        default:
            amrex_mojo::detail::release_runtime(state);
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "multifab_create received an unknown datatype."
            );
            return nullptr;
        }

        auto* multifab = new amrex_mojo_multifab{
            state,
            std::move(multifab_ptr),
            memory_kind,
            datatype,
            std::move(tiles)
        };

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
    return amrex_mojo_multifab_create_with_memory_xyz(
        runtime,
        boxarray,
        distmap,
        ncomp,
        ngrow_x,
        ngrow_y,
        ngrow_z,
        AMREX_MOJO_MULTIFAB_MEMORY_DEFAULT
    );
}

extern "C" amrex_mojo_multifab_t*
amrex_mojo_multifab_create_with_memory_xyz(
    amrex_mojo_runtime_t* runtime,
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    int32_t ngrow_x,
    int32_t ngrow_y,
    int32_t ngrow_z,
    amrex_mojo_multifab_memory_kind_t memory_kind
)
{
    return amrex_mojo_multifab_create_with_memory_and_datatype_xyz(
        runtime,
        boxarray,
        distmap,
        ncomp,
        ngrow_x,
        ngrow_y,
        ngrow_z,
        memory_kind,
        AMREX_MOJO_DATATYPE_FLOAT64
    );
}

extern "C" amrex_mojo_multifab_t*
amrex_mojo_multifab_create_with_memory_and_datatype_xyz(
    amrex_mojo_runtime_t* runtime,
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    int32_t ngrow_x,
    int32_t ngrow_y,
    int32_t ngrow_z,
    amrex_mojo_multifab_memory_kind_t memory_kind,
    amrex_mojo_datatype_t datatype
)
{
    return amrex_mojo_multifab_create_with_memory_and_datatype(
        runtime,
        boxarray,
        distmap,
        ncomp,
        amrex_mojo_intvect_3d{ngrow_x, ngrow_y, ngrow_z},
        memory_kind,
        datatype
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
    if (!require_live_multifab(multifab, "multifab_ncomp")) {
        return -1;
    }

    amrex_mojo::detail::clear_last_error();
    return visit_multifab(multifab, [](const auto& value) { return value.nComp(); });
}

extern "C" amrex_mojo_intvect_3d amrex_mojo_multifab_ngrow(const amrex_mojo_multifab_t* multifab)
{
    if (!require_live_multifab(multifab, "multifab_ngrow")) {
        return amrex_mojo_intvect_3d{};
    }

    amrex_mojo::detail::clear_last_error();
    return visit_multifab(
        multifab,
        [](const auto& value) { return amrex_mojo::detail::from_intvect(value.nGrowVect()); }
    );
}

extern "C" amrex_mojo_datatype_t
amrex_mojo_multifab_datatype(const amrex_mojo_multifab_t* multifab)
{
    if (!require_live_multifab(multifab, "multifab_datatype")) {
        return AMREX_MOJO_DATATYPE_FLOAT64;
    }

    amrex_mojo::detail::clear_last_error();
    return multifab->datatype;
}

extern "C" amrex_mojo_status_code_t amrex_mojo_multifab_memory_info(
    const amrex_mojo_multifab_t* multifab,
    amrex_mojo_multifab_memory_info_t* out_info
)
{
    if (!require_live_multifab(multifab, "multifab_memory_info") || out_info == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_memory_info requires a non-null multifab and output pointer."
        );
    }

    const auto* arena = visit_multifab(multifab, [](const auto& value) { return value.arena(); });
    out_info->requested_kind = static_cast<int32_t>(multifab->memory_kind);
    out_info->host_accessible = (arena != nullptr && arena->isHostAccessible()) ? 1 : 0;
    out_info->device_accessible = (arena != nullptr && arena->isDeviceAccessible()) ? 1 : 0;
    out_info->is_managed = (arena != nullptr && arena->isManaged()) ? 1 : 0;
    out_info->is_device = (arena != nullptr && arena->isDevice()) ? 1 : 0;
    out_info->is_pinned = (arena != nullptr && arena->isPinned()) ? 1 : 0;
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_set_val(
    amrex_mojo_multifab_t* multifab,
    double value,
    int32_t start_comp,
    int32_t ncomp
)
{
    if (!require_live_multifab(multifab, "multifab_set_val")) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_set_val requires a non-null multifab."
        );
    }

    const auto valid = visit_multifab(
        multifab,
        [&](const auto& value_ref) {
            return validate_component_range(value_ref, start_comp, ncomp);
        }
    );
    if (valid != AMREX_MOJO_STATUS_OK) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    try {
        visit_multifab(
            multifab,
            [&](auto& value_ref) {
                using value_type = typename std::decay_t<decltype(value_ref)>::value_type;
                value_ref.setVal(
                    static_cast<value_type>(value),
                    start_comp,
                    ncomp,
                    value_ref.nGrowVect()
                );
            }
        );
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
    if (!require_live_multifab(multifab, "multifab_tile_count")) {
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

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_array4_metadata_for_mfiter(
    const amrex_mojo_multifab_t* multifab,
    const amrex_mojo_mfiter_t* mfiter,
    int32_t* data_lo,
    int32_t* data_hi,
    int64_t* stride,
    int32_t* out_ncomp
)
{
    if (data_lo == nullptr || data_hi == nullptr || stride == nullptr || out_ncomp == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_array4_metadata_for_mfiter requires non-null output pointers."
        );
    }

    const auto* tile = require_multifab_tile_for_mfiter(multifab, mfiter);
    if (tile == nullptr) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    return fill_array4_metadata_from_tile(multifab, tile, data_lo, data_hi, stride, out_ncomp);
}

extern "C" double*
amrex_mojo_multifab_data_ptr_for_mfiter(
    const amrex_mojo_multifab_t* multifab,
    const amrex_mojo_mfiter_t* mfiter
)
{
    const auto* tile = require_multifab_tile_for_mfiter(multifab, mfiter);
    if (tile == nullptr) {
        return nullptr;
    }

    if (multifab->datatype != AMREX_MOJO_DATATYPE_FLOAT64) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_data_ptr_for_mfiter requires a Float64 multifab."
        );
        return nullptr;
    }

    if (require_host_accessible(multifab, tile, "multifab_data_ptr_for_mfiter") != AMREX_MOJO_STATUS_OK) {
        return nullptr;
    }

    amrex_mojo::detail::clear_last_error();
    return data_ptr_from_tile_typed<amrex::FArrayBox>(tile);
}

extern "C" double*
amrex_mojo_multifab_data_ptr_for_mfiter_device(
    const amrex_mojo_multifab_t* multifab,
    const amrex_mojo_mfiter_t* mfiter
)
{
    const auto* tile = require_multifab_tile_for_mfiter(multifab, mfiter);
    if (tile == nullptr) {
        return nullptr;
    }

    if (multifab->datatype != AMREX_MOJO_DATATYPE_FLOAT64) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_data_ptr_for_mfiter_device requires a Float64 multifab."
        );
        return nullptr;
    }

    if (
        require_device_accessible(multifab, tile, "multifab_data_ptr_for_mfiter_device") !=
        AMREX_MOJO_STATUS_OK
    ) {
        return nullptr;
    }

    amrex_mojo::detail::clear_last_error();
    return data_ptr_from_tile_typed<amrex::FArrayBox>(tile);
}

extern "C" float*
amrex_mojo_multifab_data_ptr_for_mfiter_f32(
    const amrex_mojo_multifab_t* multifab,
    const amrex_mojo_mfiter_t* mfiter
)
{
    const auto* tile = require_multifab_tile_for_mfiter(multifab, mfiter);
    if (tile == nullptr) {
        return nullptr;
    }

    if (multifab->datatype != AMREX_MOJO_DATATYPE_FLOAT32) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_data_ptr_for_mfiter_f32 requires a Float32 multifab."
        );
        return nullptr;
    }

    if (
        require_host_accessible(multifab, tile, "multifab_data_ptr_for_mfiter_f32") !=
        AMREX_MOJO_STATUS_OK
    ) {
        return nullptr;
    }

    amrex_mojo::detail::clear_last_error();
    return data_ptr_from_tile_typed<amrex::BaseFab<float>>(tile);
}

extern "C" float*
amrex_mojo_multifab_data_ptr_for_mfiter_device_f32(
    const amrex_mojo_multifab_t* multifab,
    const amrex_mojo_mfiter_t* mfiter
)
{
    const auto* tile = require_multifab_tile_for_mfiter(multifab, mfiter);
    if (tile == nullptr) {
        return nullptr;
    }

    if (multifab->datatype != AMREX_MOJO_DATATYPE_FLOAT32) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_data_ptr_for_mfiter_device_f32 requires a Float32 multifab."
        );
        return nullptr;
    }

    if (
        require_device_accessible(multifab, tile, "multifab_data_ptr_for_mfiter_device_f32") !=
        AMREX_MOJO_STATUS_OK
    ) {
        return nullptr;
    }

    amrex_mojo::detail::clear_last_error();
    return data_ptr_from_tile_typed<amrex::BaseFab<float>>(tile);
}

extern "C" double amrex_mojo_multifab_min(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (!require_valid_component(multifab, comp, "multifab_min")) {
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    if (multifab->datatype == AMREX_MOJO_DATATYPE_FLOAT64) {
        return std::get<0>(multifab->value)->min(comp, 0);
    }
    return reduce_min_f32(*std::get<1>(multifab->value), comp);
}

extern "C" double amrex_mojo_multifab_max(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (!require_valid_component(multifab, comp, "multifab_max")) {
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    if (multifab->datatype == AMREX_MOJO_DATATYPE_FLOAT64) {
        return std::get<0>(multifab->value)->max(comp, 0);
    }
    return reduce_max_f32(*std::get<1>(multifab->value), comp);
}

extern "C" double amrex_mojo_multifab_sum(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (!require_valid_component(multifab, comp, "multifab_sum")) {
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    if (multifab->datatype == AMREX_MOJO_DATATYPE_FLOAT64) {
        return std::get<0>(multifab->value)->sum(comp);
    }
    return reduce_sum_f32(*std::get<1>(multifab->value), comp);
}

extern "C" double amrex_mojo_multifab_norm0(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (!require_valid_component(multifab, comp, "multifab_norm0")) {
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    if (multifab->datatype == AMREX_MOJO_DATATYPE_FLOAT64) {
        return std::get<0>(multifab->value)->norm0(comp);
    }
    return reduce_norm0_f32(*std::get<1>(multifab->value), comp);
}

extern "C" double amrex_mojo_multifab_norm1(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (!require_valid_component(multifab, comp, "multifab_norm1")) {
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    if (multifab->datatype == AMREX_MOJO_DATATYPE_FLOAT64) {
        return std::get<0>(multifab->value)->norm1(comp);
    }
    return reduce_norm1_f32(*std::get<1>(multifab->value), comp);
}

extern "C" double amrex_mojo_multifab_norm2(const amrex_mojo_multifab_t* multifab, int32_t comp)
{
    if (!require_valid_component(multifab, comp, "multifab_norm2")) {
        return 0.0;
    }

    amrex_mojo::detail::clear_last_error();
    if (multifab->datatype == AMREX_MOJO_DATATYPE_FLOAT64) {
        return std::get<0>(multifab->value)->norm2(comp);
    }
    return reduce_norm2_f32(*std::get<1>(multifab->value), comp);
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
    if (!require_live_multifab(multifab, "multifab_plus")) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_plus requires a non-null multifab."
        );
    }

    const auto valid = visit_multifab(
        multifab,
        [&](const auto& value_ref) {
            return validate_component_range(value_ref, start_comp, ncomp);
        }
    );
    if (valid != AMREX_MOJO_STATUS_OK) {
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
        visit_multifab(
            multifab,
            [&](auto& value_ref) {
                using value_type = typename std::decay_t<decltype(value_ref)>::value_type;
                value_ref.plus(static_cast<value_type>(value), start_comp, ncomp, scalar_ngrow);
            }
        );
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
    if (!require_live_multifab(multifab, "multifab_mult")) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_mult requires a non-null multifab."
        );
    }

    const auto valid = visit_multifab(
        multifab,
        [&](const auto& value_ref) {
            return validate_component_range(value_ref, start_comp, ncomp);
        }
    );
    if (valid != AMREX_MOJO_STATUS_OK) {
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
        visit_multifab(
            multifab,
            [&](auto& value_ref) {
                using value_type = typename std::decay_t<decltype(value_ref)>::value_type;
                value_ref.mult(static_cast<value_type>(value), start_comp, ncomp, scalar_ngrow);
            }
        );
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
    if (
        !require_live_multifab(dst_multifab, "multifab_copy") ||
        !require_live_multifab(src_multifab, "multifab_copy")
    ) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_copy requires non-null source and destination multifabs."
        );
    }

    const auto src_valid = visit_multifab(
        src_multifab,
        [&](const auto& value_ref) {
            return validate_component_range(value_ref, src_comp, ncomp);
        }
    );
    const auto dst_valid = visit_multifab(
        dst_multifab,
        [&](const auto& value_ref) {
            return validate_component_range(value_ref, dst_comp, ncomp);
        }
    );
    if (src_valid != AMREX_MOJO_STATUS_OK || dst_valid != AMREX_MOJO_STATUS_OK) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    try {
        visit_multifab_pair(
            dst_multifab,
            src_multifab,
            [&](auto& dst_value, const auto& src_value) {
                amrex::Copy(
                    dst_value,
                    src_value,
                    src_comp,
                    dst_comp,
                    ncomp,
                    amrex_mojo::detail::to_intvect(ngrow)
                );
            }
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
amrex_mojo_multifab_parallel_copy(
    amrex_mojo_multifab_t* dst_multifab,
    const amrex_mojo_multifab_t* src_multifab,
    const amrex_mojo_geometry_t* geometry,
    int32_t src_comp,
    int32_t dst_comp,
    int32_t ncomp,
    amrex_mojo_intvect_3d src_ngrow,
    amrex_mojo_intvect_3d dst_ngrow
)
{
    if (
        !require_live_multifab(dst_multifab, "multifab_parallel_copy") ||
        !require_live_multifab(src_multifab, "multifab_parallel_copy") ||
        geometry == nullptr
    ) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_parallel_copy requires non-null source, destination, and geometry."
        );
    }

    if (dst_multifab->datatype != src_multifab->datatype) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_parallel_copy requires source and destination multifabs with matching datatypes."
        );
    }

    const auto src_valid = visit_multifab(
        src_multifab,
        [&](const auto& value_ref) {
            return validate_component_range(value_ref, src_comp, ncomp);
        }
    );
    const auto dst_valid = visit_multifab(
        dst_multifab,
        [&](const auto& value_ref) {
            return validate_component_range(value_ref, dst_comp, ncomp);
        }
    );
    if (src_valid != AMREX_MOJO_STATUS_OK || dst_valid != AMREX_MOJO_STATUS_OK) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    try {
        if (dst_multifab->datatype == AMREX_MOJO_DATATYPE_FLOAT64) {
            std::get<0>(dst_multifab->value)->ParallelCopy(
                *std::get<0>(src_multifab->value),
                src_comp,
                dst_comp,
                ncomp,
                amrex_mojo::detail::to_intvect(src_ngrow),
                amrex_mojo::detail::to_intvect(dst_ngrow),
                geometry->value.periodicity()
            );
        } else {
            std::get<1>(dst_multifab->value)->ParallelCopy(
                *std::get<1>(src_multifab->value),
                src_comp,
                dst_comp,
                ncomp,
                amrex_mojo::detail::to_intvect(src_ngrow),
                amrex_mojo::detail::to_intvect(dst_ngrow),
                geometry->value.periodicity()
            );
        }
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "multifab_parallel_copy failed with an unknown exception."
        );
    }
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_multifab_fill_boundary(
    amrex_mojo_multifab_t* multifab,
    const amrex_mojo_geometry_t* geometry,
    int32_t start_comp,
    int32_t ncomp,
    int32_t cross
)
{
    if (!require_live_multifab(multifab, "multifab_fill_boundary") || geometry == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "multifab_fill_boundary requires a non-null multifab and geometry."
        );
    }

    const auto valid = visit_multifab(
        multifab,
        [&](const auto& value_ref) {
            return validate_component_range(value_ref, start_comp, ncomp);
        }
    );
    if (valid != AMREX_MOJO_STATUS_OK) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    try {
        visit_multifab(
            multifab,
            [&](auto& value_ref) {
                value_ref.FillBoundary(
                    start_comp,
                    ncomp,
                    geometry->value.periodicity(),
                    cross != 0
                );
            }
        );
        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
    } catch (...) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "multifab_fill_boundary failed with an unknown exception."
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
    if (!require_live_multifab(multifab, "write_single_level_plotfile") || geometry == nullptr || plotfile == nullptr ||
        std::string(plotfile).empty()) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "write_single_level_plotfile requires non-null multifab, geometry, and plotfile path."
        );
    }

    try {
        amrex::Vector<std::string> varnames;
        const auto ncomp = visit_multifab(multifab, [](const auto& value) { return value.nComp(); });
        varnames.reserve(ncomp);
        for (int comp = 0; comp < ncomp; ++comp) {
            varnames.push_back("Var" + std::to_string(comp));
        }

        visit_multifab(
            multifab,
            [&](const auto& value_ref) {
                using multifab_type = std::decay_t<decltype(value_ref)>;
                if constexpr (std::is_same_v<multifab_type, amrex::MultiFab>) {
                    amrex::WriteSingleLevelPlotfile(
                        std::string(plotfile),
                        value_ref,
                        varnames,
                        geometry->value,
                        time,
                        level_step
                    );
                } else {
                    auto plot_multifab = amrex::MultiFab(
                        value_ref.boxArray(),
                        value_ref.DistributionMap(),
                        value_ref.nComp(),
                        value_ref.nGrowVect(),
                        amrex::MFInfo().SetArena(amrex::The_Pinned_Arena())
                    );
                    amrex::Copy(
                        plot_multifab,
                        value_ref,
                        0,
                        0,
                        value_ref.nComp(),
                        value_ref.nGrowVect()
                    );
                    amrex::Gpu::streamSynchronize();
                    amrex::WriteSingleLevelPlotfile(
                        std::string(plotfile),
                        plot_multifab,
                        varnames,
                        geometry->value,
                        time,
                        level_step
                    );
                }
            }
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
