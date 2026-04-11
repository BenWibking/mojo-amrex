#include "capi_internal.H"

#include <AMReX_GpuDevice.H>

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
