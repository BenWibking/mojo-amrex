#include "capi_internal.H"

#include <AMReX_GpuDevice.H>

#include <stdexcept>

namespace
{
#if defined(AMREX_USE_CUDA) || defined(AMREX_USE_HIP)
    auto to_external_stream_sync(amrex_mojo_external_stream_sync_t value)
        -> amrex::Gpu::ExternalStreamSync
    {
        switch (value) {
        case AMREX_MOJO_EXTERNAL_STREAM_SYNC_YES:
            return amrex::Gpu::ExternalStreamSync::Yes;
        case AMREX_MOJO_EXTERNAL_STREAM_SYNC_NO:
            return amrex::Gpu::ExternalStreamSync::No;
        default:
            throw std::invalid_argument("unknown external stream sync mode");
        }
    }

    struct external_gpu_stream_scope_impl
    {
        explicit external_gpu_stream_scope_impl(
            amrex::gpuStream_t stream,
            amrex::Gpu::ExternalStreamSync sync_on_exit
        )
            : region(stream, sync_on_exit)
        {
        }

        amrex::Gpu::ExternalGpuStreamRegion region;
    };
#endif
}

extern "C" amrex_mojo_gpu_backend_t amrex_mojo_gpu_backend(void)
{
#if defined(AMREX_USE_CUDA)
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_GPU_BACKEND_CUDA;
#elif defined(AMREX_USE_HIP)
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_GPU_BACKEND_HIP;
#else
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_GPU_BACKEND_NONE;
#endif
}

extern "C" int32_t amrex_mojo_gpu_device_id(void)
{
#if defined(AMREX_USE_CUDA) || defined(AMREX_USE_HIP)
    if (!amrex::Initialized()) {
        amrex_mojo::detail::clear_last_error();
        return -1;
    }

    amrex_mojo::detail::clear_last_error();
    return amrex::Gpu::Device::deviceId();
#else
    amrex_mojo::detail::clear_last_error();
    return -1;
#endif
}

extern "C" int32_t amrex_mojo_gpu_num_streams(void)
{
    if (!amrex::Initialized()) {
        amrex_mojo::detail::clear_last_error();
        return 1;
    }

    amrex_mojo::detail::clear_last_error();
    return amrex::Gpu::Device::numGpuStreams();
}

extern "C" amrex_mojo_status_code_t
amrex_mojo_gpu_set_stream_index(int32_t stream_index)
{
    if (!amrex::Initialized()) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "gpu_set_stream_index requires an initialized AMReX runtime."
        );
    }

    const auto num_streams = amrex::Gpu::Device::numGpuStreams();
    if (stream_index < 0 || stream_index >= num_streams) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "gpu_set_stream_index requires an index in the active stream range."
        );
    }

    amrex::Gpu::Device::setStreamIndex(stream_index);
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" void amrex_mojo_gpu_reset_stream(void)
{
    if (!amrex::Initialized()) {
        amrex_mojo::detail::clear_last_error();
        return;
    }

    amrex::Gpu::Device::resetStreamIndex();
    amrex_mojo::detail::clear_last_error();
}

extern "C" void* amrex_mojo_gpu_stream(void)
{
#if defined(AMREX_USE_CUDA) || defined(AMREX_USE_HIP)
    if (!amrex::Initialized()) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "gpu_stream requires an initialized AMReX runtime."
        );
        return nullptr;
    }

    amrex_mojo::detail::clear_last_error();
    return reinterpret_cast<void*>(amrex::Gpu::gpuStream());
#else
    amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_UNIMPLEMENTED,
        "gpu_stream requires an AMReX build with CUDA or HIP enabled."
    );
    return nullptr;
#endif
}

extern "C" amrex_mojo_status_code_t amrex_mojo_gpu_stream_synchronize_active(void)
{
    if (!amrex::Initialized()) {
        return amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "gpu_stream_synchronize_active requires an initialized AMReX runtime."
        );
    }

    amrex::Gpu::Device::streamSynchronizeActive();
    amrex_mojo::detail::clear_last_error();
    return AMREX_MOJO_STATUS_OK;
}

extern "C" amrex_mojo_external_gpu_stream_scope_t*
amrex_mojo_external_gpu_stream_scope_create(
    void* stream_handle,
    amrex_mojo_external_stream_sync_t sync_on_exit
)
{
    if (!amrex::Initialized()) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "external_gpu_stream_scope_create requires an initialized AMReX runtime."
        );
        return nullptr;
    }

    if (stream_handle == nullptr) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
            "external_gpu_stream_scope_create requires a non-null stream handle."
        );
        return nullptr;
    }

    try {
        switch (sync_on_exit) {
        case AMREX_MOJO_EXTERNAL_STREAM_SYNC_YES:
        case AMREX_MOJO_EXTERNAL_STREAM_SYNC_NO:
            break;
        default:
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "unknown external stream sync mode"
            );
            return nullptr;
        }

#if defined(AMREX_USE_CUDA) || defined(AMREX_USE_HIP)
        const auto sync_mode = to_external_stream_sync(sync_on_exit);
        auto* scope = new amrex_mojo_external_gpu_stream_scope{};
        scope->impl = new external_gpu_stream_scope_impl(
            reinterpret_cast<amrex::gpuStream_t>(stream_handle),
            sync_mode
        );
        amrex_mojo::detail::clear_last_error();
        return scope;
#else
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_UNIMPLEMENTED,
            "external_gpu_stream_scope_create requires an AMReX build with CUDA or HIP enabled."
        );
        return nullptr;
#endif
    } catch (const std::exception& ex) {
        amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
        return nullptr;
    } catch (...) {
        amrex_mojo::detail::set_last_error(
            AMREX_MOJO_STATUS_INTERNAL_ERROR,
            "external_gpu_stream_scope_create failed with an unknown exception."
        );
        return nullptr;
    }
}

extern "C" void
amrex_mojo_external_gpu_stream_scope_destroy(amrex_mojo_external_gpu_stream_scope_t* scope)
{
    if (scope == nullptr) {
        amrex_mojo::detail::clear_last_error();
        return;
    }

#if defined(AMREX_USE_CUDA) || defined(AMREX_USE_HIP)
    delete static_cast<external_gpu_stream_scope_impl*>(scope->impl);
#else
    (void)scope->impl;
#endif
    delete scope;
    amrex_mojo::detail::clear_last_error();
}
