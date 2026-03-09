#include "capi_internal.H"

extern "C" amrex_mojo_distmap_t*
amrex_mojo_distmap_create_from_boxarray(amrex_mojo_runtime_t* runtime, const amrex_mojo_boxarray_t* boxarray)
{
    if (runtime == nullptr || runtime->state == nullptr || boxarray == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "distmap_create_from_boxarray requires a live runtime and a non-null boxarray."
        );
        return nullptr;
    }

    auto* state = amrex_mojo::detail::retain_runtime(runtime->state);
    try {
        auto* distmap = new amrex_mojo_distmap{
            state,
            amrex::DistributionMapping(boxarray->value)
        };
        amrex_mojo::detail::clear_last_error();
        return distmap;
    } catch (const std::exception& ex) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
        return nullptr;
    } catch (...) {
        amrex_mojo::detail::release_runtime(state);
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "distmap_create_from_boxarray failed with an unknown exception."
        );
        return nullptr;
    }
}

extern "C" void amrex_mojo_distmap_destroy(amrex_mojo_distmap_t* distmap)
{
    if (distmap == nullptr) {
        amrex_mojo::detail::clear_last_error();
        return;
    }

    auto* state = distmap->state;
    delete distmap;
    amrex_mojo::detail::release_runtime(state);
    amrex_mojo::detail::clear_last_error();
}
