#pragma once

#include "amrex_mojo_capi.h"

#include <AMReX.H>
#include <AMReX_Array4.H>
#include <AMReX_Box.H>
#include <AMReX_BoxArray.H>
#include <AMReX_DistributionMapping.H>
#include <AMReX_FArrayBox.H>
#include <AMReX_Geometry.H>
#include <AMReX_MFIter.H>
#include <AMReX_MultiFab.H>
#include <AMReX_ParallelDescriptor.H>
#include <AMReX_ParmParse.H>
#include <AMReX_PlotFileUtil.H>

#include <atomic>
#include <memory>
#include <string>
#include <variant>
#include <vector>

#if defined(AMREX_USE_GPU)
#error "mojo-amrex does not support AMReX GPU backends. Build AMReX with AMReX_GPU_BACKEND=NONE."
#endif

namespace amrex_mojo::detail
{
    struct runtime_state
    {
        std::atomic<int32_t> ref_count{0};
        bool owns_initialization = false;
    };

    struct tile_descriptor
    {
        amrex::Box tile_box;
        amrex::Box valid_box;
        amrex::Box fab_box;
        int32_t box_index = 0;
        int32_t local_tile_index = 0;
        void* fab = nullptr;
    };

    using multifab_storage_t = std::variant<
        std::unique_ptr<amrex::MultiFab>,
        std::unique_ptr<amrex::fMultiFab>>;

    void clear_last_error() noexcept;

    amrex_mojo_status_code_t
    set_last_error(amrex_mojo_status_code_t code, const char* message) noexcept;

    amrex_mojo_status_code_t
    set_last_error(amrex_mojo_status_code_t code, const std::string& message) noexcept;

    runtime_state* retain_runtime(runtime_state* state) noexcept;
    void release_runtime(runtime_state* state) noexcept;

    inline amrex::IntVect to_intvect(amrex_mojo_intvect_3d value) noexcept
    {
        return amrex::IntVect(AMREX_D_DECL(value.x, value.y, value.z));
    }

    inline amrex_mojo_intvect_3d from_intvect(const amrex::IntVect& value) noexcept
    {
        return amrex_mojo_intvect_3d{
            value[0],
            value[1],
            value[2]
        };
    }

    inline amrex::Box to_box(amrex_mojo_box_3d value) noexcept
    {
        return amrex::Box(to_intvect(value.small_end), to_intvect(value.big_end), to_intvect(value.nodal));
    }

    inline amrex_mojo_box_3d from_box(const amrex::Box& value) noexcept
    {
        return amrex_mojo_box_3d{
            from_intvect(value.smallEnd()),
            from_intvect(value.bigEnd()),
            from_intvect(value.type())
        };
    }

    inline amrex::RealBox unit_realbox() noexcept
    {
        return amrex::RealBox(AMREX_D_DECL(0.0, 0.0, 0.0), AMREX_D_DECL(1.0, 1.0, 1.0));
    }

    inline amrex_mojo_realbox_3d from_realbox(const amrex::RealBox& value) noexcept
    {
        return amrex_mojo_realbox_3d{
            value.lo(0),
            value.lo(1),
            value.lo(2),
            value.hi(0),
            value.hi(1),
            value.hi(2)
        };
    }

    inline amrex_mojo_realvect_3d from_cell_size(const amrex::Geometry& geometry) noexcept
    {
        return amrex_mojo_realvect_3d{
            geometry.CellSize(0),
            geometry.CellSize(1),
            geometry.CellSize(2)
        };
    }

    inline int32_t to_scalar_ngrow(amrex_mojo_intvect_3d ngrow)
    {
        if (ngrow.x != ngrow.y || ngrow.x != ngrow.z) {
            return -1;
        }
        return ngrow.x;
    }
}

struct amrex_mojo_runtime
{
    amrex_mojo::detail::runtime_state* state = nullptr;
};

struct amrex_mojo_boxarray
{
    amrex_mojo::detail::runtime_state* state = nullptr;
    amrex::BoxArray value;
};

struct amrex_mojo_distmap
{
    amrex_mojo::detail::runtime_state* state = nullptr;
    amrex::DistributionMapping value;
};

struct amrex_mojo_geometry
{
    amrex_mojo::detail::runtime_state* state = nullptr;
    amrex::Geometry value;
};

struct amrex_mojo_multifab
{
    amrex_mojo::detail::runtime_state* state = nullptr;
    amrex_mojo::detail::multifab_storage_t value;
    amrex_mojo_multifab_memory_kind_t memory_kind = AMREX_MOJO_MULTIFAB_MEMORY_DEFAULT;
    amrex_mojo_datatype_t datatype = AMREX_MOJO_DATATYPE_FLOAT64;
    std::vector<amrex_mojo::detail::tile_descriptor> tiles;
};

struct amrex_mojo_mfiter
{
    amrex_mojo::detail::runtime_state* state = nullptr;
    amrex_mojo_intvect_3d ngrow{};
    std::vector<amrex_mojo::detail::tile_descriptor> tiles;
    int32_t current_tile = 0;
};

struct amrex_mojo_parmparse
{
    amrex_mojo::detail::runtime_state* state = nullptr;
    std::unique_ptr<amrex::ParmParse> value;
};
