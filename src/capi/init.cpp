#include "capi_internal.H"

#include <AMReX_GpuDevice.H>

#include <algorithm>
#include <cerrno>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <mutex>
#include <string_view>
#include <vector>

namespace
{
    std::mutex g_runtime_mutex;
    amrex_mojo::detail::runtime_state* g_runtime_state = nullptr;

    struct mpi_world_size_hint
    {
        const char* env_var = nullptr;
        int32_t size = 0;
    };

    auto build_argv_storage(int32_t argc, const char* const* argv) -> std::vector<std::string>
    {
        std::vector<std::string> args;
        if (argc <= 0) {
            args.emplace_back("mojo-amrex");
        } else {
            args.reserve(static_cast<std::size_t>(argc) + 1);
            for (int32_t i = 0; i < argc; ++i) {
                args.emplace_back(argv[i] != nullptr ? argv[i] : "");
            }
        }

        const auto has_device_arena_init_size = std::any_of(
            args.begin(),
            args.end(),
            [](const std::string& arg) {
                constexpr std::string_view prefix = "amrex.the_device_arena_init_size=";
                return arg.compare(0, prefix.size(), prefix) == 0;
            }
        );
        if (!has_device_arena_init_size) {
            args.emplace_back("amrex.the_device_arena_init_size=0");
        }

        return args;
    }

    auto build_argv_ptrs(std::vector<std::string>& args) -> std::vector<char*>
    {
        std::vector<char*> argv_ptrs;
        argv_ptrs.reserve(args.size() + 1);
        for (auto& arg : args) {
            argv_ptrs.push_back(arg.data());
        }
        argv_ptrs.push_back(nullptr);
        return argv_ptrs;
    }

    void initialize_default_parmparse()
    {
        amrex::ParmParse pp("amrex");
        amrex::Long arena_init_size = 0;
        amrex::Long device_arena_init_size = 0;
        pp.queryAdd("the_arena_init_size", arena_init_size);
        pp.queryAdd("the_device_arena_init_size", device_arena_init_size);
    }

    auto parse_positive_env_int(const char* env_var) -> int32_t
    {
        const char* value = std::getenv(env_var);
        if (value == nullptr || *value == '\0') {
            return 0;
        }

        errno = 0;
        char* end = nullptr;
        const long parsed = std::strtol(value, &end, 10);
        if (errno != 0 || end == value || *end != '\0' || parsed <= 0
            || parsed > std::numeric_limits<int32_t>::max())
        {
            return 0;
        }

        return static_cast<int32_t>(parsed);
    }

    auto detect_mpi_world_size_from_environment() -> mpi_world_size_hint
    {
        static constexpr const char* env_vars[] = {
            "OMPI_COMM_WORLD_SIZE",
            "PMI_SIZE",
            "PMIX_SIZE",
            "MV2_COMM_WORLD_SIZE"
        };

        for (const auto* env_var : env_vars) {
            const auto size = parse_positive_env_int(env_var);
            if (size > 0) {
                return mpi_world_size_hint{env_var, size};
            }
        }

        return {};
    }

    auto non_mpi_launch_error(const mpi_world_size_hint& hint) -> std::string
    {
        std::string message =
            "The loaded AMReX Mojo library was built without MPI, but this process was launched "
            "under MPI";
        if (hint.env_var != nullptr && hint.size > 0) {
            message += " with ";
            message += hint.env_var;
            message += "=";
            message += std::to_string(hint.size);
        }
        message +=
            ". Rebuild the default MPI-enabled library with `pixi run bootstrap`, "
            "or set AMREX_MOJO_LIBRARY_PATH to the rebuilt AMReX Mojo C API library.";
        return message;
    }

    auto active_amrex_gpu_device_id() -> int32_t
    {
#if defined(AMREX_USE_CUDA) || defined(AMREX_USE_HIP)
        if (amrex::Initialized()) {
            return amrex::Gpu::Device::deviceId();
        }
#endif
        return -1;
    }

    auto validate_requested_gpu_device(
        int32_t device_id,
        amrex_mojo_status_code_t& out_code,
        std::string& out_message
    ) -> bool
    {
        if (device_id < 0) {
            out_code = AMREX_MOJO_STATUS_INVALID_ARGUMENT;
            out_message = "runtime_create_on_device requires device_id >= 0.";
            return false;
        }

        int gpu_device_count = 0;

#if defined(AMREX_USE_CUDA)
        const auto err = cudaGetDeviceCount(&gpu_device_count);
        if (err != cudaSuccess) {
            out_code = AMREX_MOJO_STATUS_INTERNAL_ERROR;
            out_message =
                std::string("runtime_create_on_device failed to query CUDA device count: ") +
                cudaGetErrorString(err);
            return false;
        }
#elif defined(AMREX_USE_HIP)
        const auto err = hipGetDeviceCount(&gpu_device_count);
        if (err != hipSuccess) {
            out_code = AMREX_MOJO_STATUS_INTERNAL_ERROR;
            out_message =
                std::string("runtime_create_on_device failed to query HIP device count: ") +
                hipGetErrorString(err);
            return false;
        }
#else
        out_code = AMREX_MOJO_STATUS_UNIMPLEMENTED;
        out_message =
            "runtime_create_on_device requires an AMReX build with CUDA or HIP enabled.";
        return false;
#endif

        if (gpu_device_count <= 0) {
            out_code = AMREX_MOJO_STATUS_INVALID_ARGUMENT;
            out_message =
                "runtime_create_on_device requires at least one visible GPU device.";
            return false;
        }

        if (device_id >= gpu_device_count) {
            out_code = AMREX_MOJO_STATUS_INVALID_ARGUMENT;
            out_message =
                "runtime_create_on_device requested device_id " +
                std::to_string(device_id) +
                ", but only " + std::to_string(gpu_device_count) +
                " GPU device(s) are visible.";
            return false;
        }

        out_code = AMREX_MOJO_STATUS_OK;
        out_message.clear();
        return true;
    }

    void initialize_amrex_runtime(
        int& argc,
        char**& argv,
        bool use_parmparse,
        bool use_device_id,
        int32_t device_id
    )
    {
        if (use_device_id) {
            amrex::Initialize(
                argc,
                argv,
                use_parmparse,
                MPI_COMM_WORLD,
                initialize_default_parmparse,
                std::cout,
                std::cerr,
                nullptr,
                device_id
            );
        } else {
            amrex::Initialize(
                argc,
                argv,
                use_parmparse,
                MPI_COMM_WORLD,
                initialize_default_parmparse
            );
        }
    }

    auto runtime_create_impl(
        int32_t argc,
        const char* const* argv,
        int32_t use_parmparse,
        bool use_device_id,
        int32_t device_id
    ) -> amrex_mojo_runtime_t*
    {
        if (argc < 0) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "runtime_create requires argc >= 0."
            );
            return nullptr;
        }

        if (argc > 0 && argv == nullptr) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                "runtime_create requires argv when argc > 0."
            );
            return nullptr;
        }

        if (use_device_id) {
            amrex_mojo_status_code_t status = AMREX_MOJO_STATUS_OK;
            std::string message;
            if (!validate_requested_gpu_device(device_id, status, message)) {
                amrex_mojo::detail::set_last_error(status, message);
                return nullptr;
            }
        }

        try {
            std::lock_guard<std::mutex> lock(g_runtime_mutex);

            auto* state = g_runtime_state;
            if (use_device_id && amrex::Initialized()) {
                const auto active_device_id = active_amrex_gpu_device_id();
                if (active_device_id < 0) {
                    amrex_mojo::detail::set_last_error(
                        AMREX_MOJO_STATUS_UNIMPLEMENTED,
                        "AMReX is already initialized without CUDA or HIP device support."
                    );
                    return nullptr;
                }
                if (active_device_id != device_id) {
                    amrex_mojo::detail::set_last_error(
                        AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                        "AMReX is already initialized on a different GPU device and cannot "
                        "switch devices without finalizing the runtime."
                    );
                    return nullptr;
                }
            }

            if (state == nullptr) {
                if (!amrex::Initialized()) {
#if !defined(AMREX_USE_MPI)
                    const auto mpi_world_size = detect_mpi_world_size_from_environment();
                    if (mpi_world_size.size > 1) {
                        amrex_mojo::detail::set_last_error(
                            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
                            non_mpi_launch_error(mpi_world_size)
                        );
                        return nullptr;
                    }
#endif

                    auto* new_state = new amrex_mojo::detail::runtime_state{};
                    auto argv_storage = build_argv_storage(argc, argv);
                    auto argv_ptrs = build_argv_ptrs(argv_storage);
                    int argc_local = static_cast<int>(argv_storage.size());
                    char** argv_local = argv_ptrs.data();
                    initialize_amrex_runtime(
                        argc_local,
                        argv_local,
                        use_parmparse != 0,
                        use_device_id,
                        device_id
                    );
                    new_state->owns_initialization = true;
                    state = new_state;
                    g_runtime_state = state;
                } else {
                    auto* new_state = new amrex_mojo::detail::runtime_state{};
                    state = new_state;
                    g_runtime_state = state;
                }
            }

            auto* runtime = new amrex_mojo_runtime{state};
            amrex_mojo::detail::retain_runtime(state);
            amrex_mojo::detail::clear_last_error();
            return runtime;
        } catch (const std::exception& ex) {
            amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INTERNAL_ERROR, ex.what());
            return nullptr;
        } catch (...) {
            amrex_mojo::detail::set_last_error(
                AMREX_MOJO_STATUS_INTERNAL_ERROR,
                "runtime_create failed with an unknown exception."
            );
            return nullptr;
        }
    }
}

namespace amrex_mojo::detail
{
    runtime_state* retain_runtime(runtime_state* state) noexcept
    {
        if (state != nullptr) {
            state->ref_count.fetch_add(1, std::memory_order_relaxed);
        }
        return state;
    }

    void release_runtime(runtime_state* state) noexcept
    {
        if (state == nullptr) {
            return;
        }

        bool should_delete = false;
        bool should_finalize = false;
        {
            std::lock_guard<std::mutex> lock(g_runtime_mutex);
            const auto previous = state->ref_count.fetch_sub(1, std::memory_order_acq_rel);
            if (previous == 1) {
                should_delete = true;
                should_finalize = state->owns_initialization;
                if (g_runtime_state == state) {
                    g_runtime_state = nullptr;
                }
            }
        }

        if (!should_delete) {
            return;
        }

        if (should_finalize) {
            try {
                if (amrex::Initialized()) {
                    amrex::Finalize();
                }
            } catch (...) {
            }
        }

        delete state;
    }
}

extern "C" amrex_mojo_runtime_t*
amrex_mojo_runtime_create(int32_t argc, const char* const* argv, int32_t use_parmparse)
{
    return runtime_create_impl(argc, argv, use_parmparse, false, -1);
}

extern "C" amrex_mojo_runtime_t* amrex_mojo_runtime_create_default(void)
{
    return amrex_mojo_runtime_create(0, nullptr, 0);
}

extern "C" amrex_mojo_runtime_t*
amrex_mojo_runtime_create_on_device(
    int32_t argc,
    const char* const* argv,
    int32_t use_parmparse,
    int32_t device_id
)
{
    return runtime_create_impl(argc, argv, use_parmparse, true, device_id);
}

extern "C" amrex_mojo_runtime_t*
amrex_mojo_runtime_create_default_on_device(int32_t device_id)
{
    return amrex_mojo_runtime_create_on_device(0, nullptr, 0, device_id);
}

extern "C" void amrex_mojo_runtime_destroy(amrex_mojo_runtime_t* runtime)
{
    if (runtime == nullptr) {
        amrex_mojo::detail::clear_last_error();
        return;
    }

    auto* state = runtime->state;
    delete runtime;
    amrex_mojo::detail::release_runtime(state);
    amrex_mojo::detail::clear_last_error();
}

extern "C" int32_t amrex_mojo_runtime_initialized(const amrex_mojo_runtime_t* runtime)
{
    amrex_mojo::detail::clear_last_error();
    return (runtime != nullptr && runtime->state != nullptr && amrex::Initialized()) ? 1 : 0;
}

extern "C" int32_t amrex_mojo_parallel_nprocs(void)
{
    amrex_mojo::detail::clear_last_error();
    return amrex::Initialized() ? amrex::ParallelDescriptor::NProcs() : 0;
}

extern "C" int32_t amrex_mojo_parallel_myproc(void)
{
    amrex_mojo::detail::clear_last_error();
    return amrex::Initialized() ? amrex::ParallelDescriptor::MyProc() : 0;
}

extern "C" int32_t amrex_mojo_parallel_ioprocessor(void)
{
    amrex_mojo::detail::clear_last_error();
    return amrex::Initialized() ? static_cast<int32_t>(amrex::ParallelDescriptor::IOProcessor()) : 0;
}

extern "C" int32_t amrex_mojo_parallel_ioprocessor_number(void)
{
    amrex_mojo::detail::clear_last_error();
    return amrex::Initialized() ? amrex::ParallelDescriptor::IOProcessorNumber() : 0;
}
