#include "capi_internal.H"

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

    auto require_current_tile(const amrex_mojo_mfiter_t* mfiter)
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

    auto grown_tile_box(
        const amrex_mojo::detail::tile_descriptor& tile,
        amrex_mojo_intvect_3d ngrow
    ) -> amrex::Box
    {
        auto box = tile.tile_box;
        const auto grow = amrex_mojo::detail::to_intvect(ngrow);
        for (int d = 0; d < AMREX_SPACEDIM; ++d) {
            if (box.smallEnd(d) == tile.valid_box.smallEnd(d)) {
                box.growLo(d, grow[d]);
            }
            if (box.bigEnd(d) == tile.valid_box.bigEnd(d)) {
                box.growHi(d, grow[d]);
            }
        }
        return box;
    }
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_mfiter_create(amrex_mojo_multifab_t* multifab, amrex_mojo_mfiter_t** out_mfiter)
{
    if (multifab == nullptr || multifab->value == nullptr || out_mfiter == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "mfiter_create requires a non-null multifab and output pointer."
        );
    }

    *out_mfiter = nullptr;

    auto* state = amrex_mojo::detail::retain_runtime(multifab->state);
    try {
        std::vector<amrex_mojo::detail::tile_descriptor> tiles;
        tiles.reserve(multifab->tiles.size());
        for (const auto& tile : multifab->tiles) {
            tiles.push_back(amrex_mojo::detail::tile_descriptor{
                tile.tile_box,
                tile.valid_box,
                tile.fab_box,
                tile.box_index,
                tile.local_tile_index,
                nullptr
            });
        }

        *out_mfiter = new amrex_mojo_mfiter{
            state,
            amrex_mojo::detail::from_intvect(multifab->value->nGrowVect()),
            std::move(tiles),
            0
        };

        amrex_mojo::detail::clear_last_error();
        return AMREX_MOJO_STATUS_OK;
    } catch (const std::exception& ex) {
        amrex_mojo::detail::release_runtime(state);
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            ex.what()
        );
    } catch (...) {
        amrex_mojo::detail::release_runtime(state);
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "mfiter_create failed with an unknown exception."
        );
    }
}

extern "C" void amrex_mojo_mfiter_destroy(amrex_mojo_mfiter_t* mfiter)
{
    if (mfiter == nullptr) {
        amrex_mojo::detail::clear_last_error();
        return;
    }

    auto* state = mfiter->state;
    delete mfiter;
    amrex_mojo::detail::release_runtime(state);
    amrex_mojo::detail::clear_last_error();
}

extern "C" int32_t amrex_mojo_mfiter_is_valid(const amrex_mojo_mfiter_t* mfiter)
{
    if (mfiter == nullptr) {
        amrex_mojo::detail::clear_last_error();
        return 0;
    }

    amrex_mojo::detail::clear_last_error();
    return (
        mfiter->current_tile >= 0 &&
        mfiter->current_tile < static_cast<int32_t>(mfiter->tiles.size())
    ) ? 1 : 0;
}

extern "C" amrex_mojo_status_code_t amrex_mojo_mfiter_next(amrex_mojo_mfiter_t* mfiter)
{
    if (mfiter == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "mfiter_next requires a non-null iterator."
        );
    }

    if (mfiter->current_tile < 0 ||
        mfiter->current_tile >= static_cast<int32_t>(mfiter->tiles.size())) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "mfiter is not in a valid iteration state."
        );
    }

    ++mfiter->current_tile;
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" int32_t amrex_mojo_mfiter_index(const amrex_mojo_mfiter_t* mfiter)
{
    const auto* tile = require_current_tile(mfiter);
    if (tile == nullptr) {
        return -1;
    }

    amrex_mojo::detail::clear_last_error();
    return tile->box_index;
}

extern "C" int32_t amrex_mojo_mfiter_local_tile_index(const amrex_mojo_mfiter_t* mfiter)
{
    const auto* tile = require_current_tile(mfiter);
    if (tile == nullptr) {
        return -1;
    }

    amrex_mojo::detail::clear_last_error();
    return tile->local_tile_index;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_mfiter_tile_box_metadata(
    const amrex_mojo_mfiter_t* mfiter,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
)
{
    if (out_small_end == nullptr || out_big_end == nullptr || out_nodal == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "mfiter_tile_box_metadata requires non-null output pointers."
        );
    }

    const auto* tile = require_current_tile(mfiter);
    if (tile == nullptr) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    fill_box_arrays(tile->tile_box, out_small_end, out_big_end, out_nodal);
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_mfiter_valid_box_metadata(
    const amrex_mojo_mfiter_t* mfiter,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
)
{
    if (out_small_end == nullptr || out_big_end == nullptr || out_nodal == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "mfiter_valid_box_metadata requires non-null output pointers."
        );
    }

    const auto* tile = require_current_tile(mfiter);
    if (tile == nullptr) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    fill_box_arrays(tile->valid_box, out_small_end, out_big_end, out_nodal);
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_mfiter_fab_box_metadata(
    const amrex_mojo_mfiter_t* mfiter,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
)
{
    if (out_small_end == nullptr || out_big_end == nullptr || out_nodal == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "mfiter_fab_box_metadata requires non-null output pointers."
        );
    }

    const auto* tile = require_current_tile(mfiter);
    if (tile == nullptr) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    fill_box_arrays(tile->fab_box, out_small_end, out_big_end, out_nodal);
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_mfiter_growntile_box_metadata(
    const amrex_mojo_mfiter_t* mfiter,
    amrex_mojo_intvect_3d ngrow,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
)
{
    if (out_small_end == nullptr || out_big_end == nullptr || out_nodal == nullptr) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "mfiter_growntile_box_metadata requires non-null output pointers."
        );
    }

    const auto* tile = require_current_tile(mfiter);
    if (tile == nullptr) {
        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
    }

    const auto box = grown_tile_box(*tile, ngrow);
    fill_box_arrays(box, out_small_end, out_big_end, out_nodal);
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}
