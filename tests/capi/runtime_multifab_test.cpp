#include "amrex_mojo_capi.h"

#include <cmath>
#include <cstddef>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>
#include <type_traits>

namespace
{
    constexpr int kDomainExtent = 64;

    auto close_enough(double lhs, double rhs, double tolerance = 1.0e-12) -> bool
    {
        return std::abs(lhs - rhs) <= tolerance;
    }

    void fail(const std::string& message)
    {
        std::cerr << "amrex_mojo_capi_test: " << message << '\n';
        const char* last_error = amrex_mojo_last_error_message();
        if (last_error != nullptr && last_error[0] != '\0') {
            std::cerr << "last error: " << last_error << '\n';
        }
        std::exit(1);
    }

    void expect(bool condition, const std::string& message)
    {
        if (!condition) {
            fail(message);
        }
    }

    auto box_cell_count(const amrex_mojo_box_3d& box) -> long long
    {
        const auto nx = static_cast<long long>(box.big_end.x - box.small_end.x + 1);
        const auto ny = static_cast<long long>(box.big_end.y - box.small_end.y + 1);
        const auto nz = static_cast<long long>(box.big_end.z - box.small_end.z + 1);
        return nx * ny * nz;
    }

    template <typename Array4View>
    auto array4_value(
        const Array4View& array4,
        int i,
        int j,
        int k,
        int comp = 0
    ) -> typename std::remove_cv_t<std::remove_pointer_t<decltype(array4.data)>>
    {
        const auto offset =
            static_cast<std::ptrdiff_t>(i - array4.lo_x) * array4.stride_i +
            static_cast<std::ptrdiff_t>(j - array4.lo_y) * array4.stride_j +
            static_cast<std::ptrdiff_t>(k - array4.lo_z) * array4.stride_k +
            static_cast<std::ptrdiff_t>(comp) * array4.stride_n;
        return array4.data[offset];
    }

    template <typename Array4View, typename Value>
    void fill_valid_box(
        const Array4View& array4,
        const amrex_mojo_box_3d& box,
        Value value
    )
    {
        for (int k = box.small_end.z; k <= box.big_end.z; ++k) {
            for (int j = box.small_end.y; j <= box.big_end.y; ++j) {
                for (int i = box.small_end.x; i <= box.big_end.x; ++i) {
                    const auto offset =
                        static_cast<std::ptrdiff_t>(i - array4.lo_x) * array4.stride_i +
                        static_cast<std::ptrdiff_t>(j - array4.lo_y) * array4.stride_j +
                        static_cast<std::ptrdiff_t>(k - array4.lo_z) * array4.stride_k;
                    array4.data[offset] = value;
                }
            }
        }
    }

    auto has_nonzero_ghost_cells(const amrex_mojo_multifab_t* multifab) -> bool
    {
        const auto tile_count = amrex_mojo_multifab_tile_count(multifab);
        for (int tile_index = 0; tile_index < tile_count; ++tile_index) {
            const auto valid_box = amrex_mojo_multifab_valid_box(multifab, tile_index);
            const auto array4 = amrex_mojo_multifab_array4(multifab, tile_index);
            for (int k = array4.lo_z; k <= array4.hi_z; ++k) {
                for (int j = array4.lo_y; j <= array4.hi_y; ++j) {
                    for (int i = array4.lo_x; i <= array4.hi_x; ++i) {
                        const bool in_valid =
                            i >= valid_box.small_end.x && i <= valid_box.big_end.x &&
                            j >= valid_box.small_end.y && j <= valid_box.big_end.y &&
                            k >= valid_box.small_end.z && k <= valid_box.big_end.z;
                        if (!in_valid && !close_enough(array4_value(array4, i, j, k), 0.0)) {
                            return true;
                        }
                    }
                }
            }
        }

        return false;
    }
}

auto main() -> int
{
    expect(amrex_mojo_abi_version() == AMREX_MOJO_ABI_VERSION, "ABI version mismatch.");

    expect(
        amrex_mojo_runtime_create(-1, nullptr, 0) == nullptr,
        "runtime_create should reject argc < 0."
    );
    expect(
        std::string(amrex_mojo_last_error_message()).find("argc") != std::string::npos,
        "runtime_create should report an argc validation error."
    );
    expect(
        amrex_mojo_boxarray_size(nullptr) == -1,
        "boxarray_size should reject a null boxarray."
    );
    expect(
        std::string(amrex_mojo_last_error_message()).find("boxarray") != std::string::npos,
        "boxarray_size should report a null-handle diagnostic."
    );
    expect(
        amrex_mojo_multifab_set_val(nullptr, 0.0, 0, 1) == AMREX_MOJO_STATUS_INVALID_ARGUMENT,
        "multifab_set_val should reject a null multifab."
    );
    expect(
        std::string(amrex_mojo_last_error_message()).find("multifab") != std::string::npos,
        "multifab_set_val should report a null-handle diagnostic."
    );
    expect(
        amrex_mojo_mfiter_next(nullptr) == AMREX_MOJO_STATUS_INVALID_ARGUMENT,
        "mfiter_next should reject a null iterator."
    );
    expect(
        std::string(amrex_mojo_last_error_message()).find("iterator") != std::string::npos,
        "mfiter_next should report a null-handle diagnostic."
    );

    const char* runtime_argv[] = {"amrex_mojo_capi_test"};
    amrex_mojo_runtime_t* runtime = amrex_mojo_runtime_create(1, runtime_argv, 0);
    expect(runtime != nullptr, "runtime_create returned null.");
    expect(amrex_mojo_runtime_initialized(runtime) == 1, "runtime should report initialized.");
    const auto gpu_backend = amrex_mojo_gpu_backend();
    expect(
        gpu_backend >= AMREX_MOJO_GPU_BACKEND_NONE &&
            gpu_backend <= AMREX_MOJO_GPU_BACKEND_HIP,
        "gpu_backend should return a known enum value."
    );
    const auto gpu_device_id = amrex_mojo_gpu_device_id();
    if (gpu_backend == AMREX_MOJO_GPU_BACKEND_NONE) {
        expect(
            gpu_device_id == -1,
            "gpu_device_id should report -1 when AMReX has no CUDA/HIP backend."
        );
        expect(
            amrex_mojo_runtime_create_on_device(1, runtime_argv, 0, 0) == nullptr,
            "runtime_create_on_device should fail when CUDA/HIP interop is unavailable."
        );
        expect(
            std::string(amrex_mojo_last_error_message()).find("CUDA or HIP") != std::string::npos,
            "runtime_create_on_device should report a GPU-backend diagnostic."
        );
        expect(
            amrex_mojo_external_gpu_stream_scope_create(
                reinterpret_cast<void*>(0x1),
                AMREX_MOJO_EXTERNAL_STREAM_SYNC_NO
            ) == nullptr,
            "external_gpu_stream_scope_create should fail when CUDA/HIP interop is unavailable."
        );
    } else {
        expect(gpu_device_id >= 0, "gpu_device_id should be >= 0 for CUDA/HIP builds.");
        amrex_mojo_runtime_t* same_device_runtime =
            amrex_mojo_runtime_create_on_device(1, runtime_argv, 0, gpu_device_id);
        expect(
            same_device_runtime != nullptr,
            "runtime_create_on_device should succeed on the active AMReX GPU device."
        );
        amrex_mojo_runtime_destroy(same_device_runtime);
    }
    expect(amrex_mojo_parallel_nprocs() >= 1, "parallel_nprocs should be >= 1.");
    expect(amrex_mojo_parallel_myproc() >= 0, "parallel_myproc should be >= 0.");
    expect(
        amrex_mojo_parallel_ioprocessor_number() >= 0,
        "parallel_ioprocessor_number should be >= 0."
    );

    const amrex_mojo_box_3d domain{
        amrex_mojo_intvect_3d{0, 0, 0},
        amrex_mojo_intvect_3d{kDomainExtent - 1, kDomainExtent - 1, kDomainExtent - 1},
        amrex_mojo_intvect_3d{0, 0, 0}
    };

    amrex_mojo_boxarray_t* boxarray = amrex_mojo_boxarray_create_from_box(runtime, domain);
    expect(boxarray != nullptr, "boxarray_create_from_box returned null.");
    expect(
        amrex_mojo_boxarray_max_size_xyz(boxarray, 32, 32, 32) == AMREX_MOJO_STATUS_OK,
        "boxarray_max_size_xyz failed."
    );
    expect(amrex_mojo_boxarray_size(boxarray) == 8, "boxarray should split into 8 boxes.");

    long long total_cells = 0;
    for (int i = 0; i < amrex_mojo_boxarray_size(boxarray); ++i) {
        const amrex_mojo_box_3d box = amrex_mojo_boxarray_box(boxarray, i);
        const int nx = box.big_end.x - box.small_end.x + 1;
        const int ny = box.big_end.y - box.small_end.y + 1;
        const int nz = box.big_end.z - box.small_end.z + 1;
        expect(nx > 0 && nx <= 32, "boxarray x-extent should be within the split size.");
        expect(ny > 0 && ny <= 32, "boxarray y-extent should be within the split size.");
        expect(nz > 0 && nz <= 32, "boxarray z-extent should be within the split size.");
        total_cells += box_cell_count(box);
    }
    expect(
        total_cells == static_cast<long long>(kDomainExtent) * kDomainExtent * kDomainExtent,
        "boxarray cells should cover the full domain."
    );

    amrex_mojo_distmap_t* distmap = amrex_mojo_distmap_create_from_boxarray(runtime, boxarray);
    expect(distmap != nullptr, "distmap_create_from_boxarray returned null.");

    amrex_mojo_geometry_t* geometry = amrex_mojo_geometry_create(runtime, domain);
    expect(geometry != nullptr, "geometry_create returned null.");

    const amrex_mojo_box_3d geometry_domain = amrex_mojo_geometry_domain(geometry);
    expect(
        geometry_domain.small_end.x == 0 && geometry_domain.big_end.x == kDomainExtent - 1,
        "geometry domain x-bounds mismatch."
    );
    expect(
        geometry_domain.small_end.y == 0 && geometry_domain.big_end.y == kDomainExtent - 1,
        "geometry domain y-bounds mismatch."
    );
    expect(
        geometry_domain.small_end.z == 0 && geometry_domain.big_end.z == kDomainExtent - 1,
        "geometry domain z-bounds mismatch."
    );

    const amrex_mojo_realbox_3d prob_domain = amrex_mojo_geometry_prob_domain(geometry);
    expect(
        close_enough(prob_domain.lo_x, 0.0) && close_enough(prob_domain.lo_y, 0.0) &&
            close_enough(prob_domain.lo_z, 0.0),
        "geometry prob_domain low corner mismatch."
    );
    expect(
        close_enough(prob_domain.hi_x, 1.0) && close_enough(prob_domain.hi_y, 1.0) &&
            close_enough(prob_domain.hi_z, 1.0),
        "geometry prob_domain high corner mismatch."
    );

    const amrex_mojo_realvect_3d cell_size = amrex_mojo_geometry_cell_size(geometry);
    expect(close_enough(cell_size.x, 1.0 / kDomainExtent), "geometry cell_size x mismatch.");
    expect(close_enough(cell_size.y, 1.0 / kDomainExtent), "geometry cell_size y mismatch.");
    expect(close_enough(cell_size.z, 1.0 / kDomainExtent), "geometry cell_size z mismatch.");

    const amrex_mojo_intvect_3d periodicity = amrex_mojo_geometry_periodicity(geometry);
    expect(
        periodicity.x == 0 && periodicity.y == 0 && periodicity.z == 0,
        "geometry periodicity should be all zeros."
    );

    amrex_mojo_multifab_t* multifab = amrex_mojo_multifab_create_xyz(runtime, boxarray, distmap, 1, 0, 0, 0);
    expect(multifab != nullptr, "multifab_create_xyz returned null.");
    expect(amrex_mojo_multifab_ncomp(multifab) == 1, "multifab should have one component.");
    expect(amrex_mojo_multifab_tile_count(multifab) > 0, "multifab should expose at least one tile.");

    amrex_mojo_multifab_memory_info_t default_memory{};
    expect(
        amrex_mojo_multifab_memory_info(multifab, &default_memory) == AMREX_MOJO_STATUS_OK,
        "multifab_memory_info should succeed for default allocation."
    );
    expect(
        default_memory.host_accessible == 1,
        "default multifab should be host-accessible."
    );

    amrex_mojo_multifab_t* host_multifab = amrex_mojo_multifab_create_with_memory_xyz(
        runtime,
        boxarray,
        distmap,
        1,
        0,
        0,
        0,
        AMREX_MOJO_MULTIFAB_MEMORY_HOST_ONLY
    );
    expect(host_multifab != nullptr, "host_only multifab create should succeed.");
    amrex_mojo_multifab_memory_info_t host_memory{};
    expect(
        amrex_mojo_multifab_memory_info(host_multifab, &host_memory) == AMREX_MOJO_STATUS_OK,
        "multifab_memory_info should succeed for host_only allocation."
    );
    expect(host_memory.host_accessible == 1, "host_only multifab should be host-accessible.");
    expect(
        amrex_mojo_multifab_data_ptr_device(host_multifab, 0) == nullptr,
        "host_only multifab_data_ptr_device should reject non-device storage."
    );
    expect(
        std::string(amrex_mojo_last_error_message()).find("device-accessible") !=
            std::string::npos,
        "multifab_data_ptr_device should report a device-accessibility diagnostic."
    );

    expect(
        amrex_mojo_multifab_set_val(multifab, 2.0, 0, 1) == AMREX_MOJO_STATUS_OK,
        "multifab_set_val failed."
    );
    expect(
        amrex_mojo_multifab_set_val(host_multifab, 2.0, 0, 1) == AMREX_MOJO_STATUS_OK,
        "host_multifab set_val failed."
    );

    const double expected_sum = 2.0 * static_cast<double>(total_cells);
    expect(close_enough(amrex_mojo_multifab_sum(multifab, 0), expected_sum), "multifab_sum mismatch.");
    expect(close_enough(amrex_mojo_multifab_min(multifab, 0), 2.0), "multifab_min mismatch.");
    expect(close_enough(amrex_mojo_multifab_max(multifab, 0), 2.0), "multifab_max mismatch.");
    expect(close_enough(amrex_mojo_multifab_norm0(multifab, 0), 2.0), "multifab_norm0 mismatch.");

    amrex_mojo_array4_view_f64 array4 = amrex_mojo_multifab_array4(multifab, 0);
    expect(array4.data != nullptr, "multifab_array4 should return a live data pointer.");

    array4 = amrex_mojo_multifab_array4(host_multifab, 0);
    expect(array4.data != nullptr, "host_only multifab_array4 should return a live data pointer.");
    expect(array4.ncomp == 1, "multifab_array4 should report one component.");
    array4.data[0] = 3.0;
    expect(
        close_enough(amrex_mojo_multifab_max(host_multifab, 0), 3.0),
        "array4 write should change max for host_only multifab."
    );

    amrex_mojo_multifab_t* float_multifab =
        amrex_mojo_multifab_create_with_memory_and_datatype_xyz(
            runtime,
            boxarray,
            distmap,
            1,
            0,
            0,
            0,
            AMREX_MOJO_MULTIFAB_MEMORY_HOST_ONLY,
            AMREX_MOJO_DATATYPE_FLOAT32
        );
    expect(float_multifab != nullptr, "Float32 multifab create should succeed.");
    expect(
        amrex_mojo_multifab_datatype(float_multifab) == AMREX_MOJO_DATATYPE_FLOAT32,
        "Float32 multifab should report the Float32 datatype."
    );
    expect(
        amrex_mojo_multifab_set_val(float_multifab, 1.5, 0, 1) == AMREX_MOJO_STATUS_OK,
        "Float32 multifab set_val failed."
    );
    expect(
        amrex_mojo_multifab_array4(float_multifab, 0).data == nullptr,
        "Float32 multifab_array4 should reject Float64 view access."
    );
    auto float_array4 = amrex_mojo_multifab_array4_f32(float_multifab, 0);
    expect(float_array4.data != nullptr, "Float32 multifab_array4_f32 should return a live pointer.");
    float_array4.data[0] = 2.5f;
    expect(
        close_enough(amrex_mojo_multifab_max(float_multifab, 0), 2.5),
        "Float32 array4 write should change the multifab max."
    );

    amrex_mojo_mfiter_t* float_mfiter = nullptr;
    expect(
        amrex_mojo_mfiter_create(float_multifab, &float_mfiter) == AMREX_MOJO_STATUS_OK &&
            float_mfiter != nullptr,
        "Float32 mfiter_create failed."
    );
    expect(
        amrex_mojo_multifab_data_ptr_for_mfiter_f32(float_multifab, float_mfiter) != nullptr,
        "Float32 multifab_data_ptr_for_mfiter_f32 should return a live pointer."
    );
    amrex_mojo_mfiter_destroy(float_mfiter);

    amrex_mojo_mfiter_t* mfiter = nullptr;
    expect(
        amrex_mojo_mfiter_create(host_multifab, &mfiter) == AMREX_MOJO_STATUS_OK && mfiter != nullptr,
        "mfiter_create failed."
    );

    int iterated_tiles = 0;
    while (amrex_mojo_mfiter_is_valid(mfiter) != 0) {
        int32_t tile_lo[3] = {0, 0, 0};
        int32_t tile_hi[3] = {0, 0, 0};
        int32_t nodal[3] = {0, 0, 0};
        expect(
            amrex_mojo_mfiter_tile_box_metadata(mfiter, tile_lo, tile_hi, nodal) == AMREX_MOJO_STATUS_OK,
            "mfiter_tile_box_metadata failed."
        );
        expect(tile_lo[0] <= tile_hi[0], "mfiter tile box x-bounds should be ordered.");
        expect(tile_lo[1] <= tile_hi[1], "mfiter tile box y-bounds should be ordered.");
        expect(tile_lo[2] <= tile_hi[2], "mfiter tile box z-bounds should be ordered.");
        expect(
            amrex_mojo_multifab_data_ptr_for_mfiter(host_multifab, mfiter) != nullptr,
            "host_only multifab_data_ptr_for_mfiter should return a live pointer."
        );
        ++iterated_tiles;
        expect(amrex_mojo_mfiter_next(mfiter) == AMREX_MOJO_STATUS_OK, "mfiter_next failed.");
    }
    expect(
        iterated_tiles == amrex_mojo_multifab_tile_count(host_multifab),
        "mfiter tile count mismatch."
    );
    amrex_mojo_mfiter_destroy(mfiter);

    amrex_mojo_multifab_t* comm_source =
        amrex_mojo_multifab_create_with_memory_xyz(
            runtime,
            boxarray,
            distmap,
            1,
            1,
            1,
            1,
            AMREX_MOJO_MULTIFAB_MEMORY_HOST_ONLY
        );
    expect(comm_source != nullptr, "comm_source create failed.");
    amrex_mojo_multifab_t* comm_destination =
        amrex_mojo_multifab_create_with_memory_xyz(
            runtime,
            boxarray,
            distmap,
            1,
            1,
            1,
            1,
            AMREX_MOJO_MULTIFAB_MEMORY_HOST_ONLY
        );
    expect(comm_destination != nullptr, "comm_destination create failed.");
    expect(
        amrex_mojo_multifab_set_val(comm_source, 0.0, 0, 1) == AMREX_MOJO_STATUS_OK,
        "comm_source set_val failed."
    );
    expect(
        amrex_mojo_multifab_set_val(comm_destination, 0.0, 0, 1) == AMREX_MOJO_STATUS_OK,
        "comm_destination set_val failed."
    );

    for (int tile_index = 0; tile_index < amrex_mojo_multifab_tile_count(comm_source); ++tile_index) {
        const auto tile_box = amrex_mojo_multifab_tile_box(comm_source, tile_index);
        const auto tile_array = amrex_mojo_multifab_array4(comm_source, tile_index);
        fill_valid_box(
            tile_array,
            tile_box,
            static_cast<double>(amrex_mojo_parallel_myproc() + 1)
        );
    }

    expect(!has_nonzero_ghost_cells(comm_source), "comm_source ghosts should start at zero.");
    expect(
        amrex_mojo_multifab_fill_boundary(comm_source, geometry, 0, 1, 0) == AMREX_MOJO_STATUS_OK,
        "multifab_fill_boundary failed."
    );
    expect(has_nonzero_ghost_cells(comm_source), "fill_boundary should populate ghost cells.");

    expect(
        amrex_mojo_multifab_parallel_copy(
            comm_destination,
            comm_source,
            geometry,
            0,
            0,
            1,
            amrex_mojo_intvect_3d{0, 0, 0},
            amrex_mojo_intvect_3d{1, 1, 1}
        ) == AMREX_MOJO_STATUS_OK,
        "multifab_parallel_copy failed."
    );
    expect(
        close_enough(
            amrex_mojo_multifab_sum(comm_destination, 0),
            amrex_mojo_multifab_sum(comm_source, 0)
        ),
        "parallel_copy should preserve the valid-region sum."
    );
    expect(
        has_nonzero_ghost_cells(comm_destination),
        "parallel_copy should populate destination ghost cells."
    );

    amrex_mojo_parmparse_t* parmparse = amrex_mojo_parmparse_create(runtime, "capi_test");
    expect(parmparse != nullptr, "parmparse_create returned null.");
    int32_t out_value = 0;
    int32_t out_found = 0;
    expect(
        amrex_mojo_parmparse_add_int(parmparse, "tile_fill_value", 7) == AMREX_MOJO_STATUS_OK,
        "parmparse_add_int failed."
    );
    out_value = 0;
    out_found = 0;
    expect(
        amrex_mojo_parmparse_query_int(parmparse, "tile_fill_value", &out_value, &out_found) ==
            AMREX_MOJO_STATUS_OK,
        "parmparse_query_int failed."
    );
    expect(out_found == 1 && out_value == 7, "parmparse query should return the inserted value.");

    const std::filesystem::path plotfile = "build/capi_test_plotfile";
    expect(
        amrex_mojo_write_single_level_plotfile(multifab, geometry, plotfile.string().c_str(), 0.0, 0) ==
            AMREX_MOJO_STATUS_OK,
        "write_single_level_plotfile failed."
    );
    expect(std::filesystem::exists(plotfile / "Header"), "plotfile Header was not written.");

    const std::filesystem::path float_plotfile = "build/capi_test_plotfile_f32";
    expect(
        amrex_mojo_write_single_level_plotfile(
            float_multifab,
            geometry,
            float_plotfile.string().c_str(),
            0.0,
            0
        ) == AMREX_MOJO_STATUS_OK,
        "Float32 write_single_level_plotfile failed."
    );
    expect(
        std::filesystem::exists(float_plotfile / "Header"),
        "Float32 plotfile Header was not written."
    );

    amrex_mojo_parmparse_destroy(parmparse);
    amrex_mojo_multifab_destroy(float_multifab);
    amrex_mojo_multifab_destroy(host_multifab);
    amrex_mojo_multifab_destroy(comm_destination);
    amrex_mojo_multifab_destroy(comm_source);
    amrex_mojo_multifab_destroy(multifab);
    amrex_mojo_geometry_destroy(geometry);
    amrex_mojo_distmap_destroy(distmap);
    amrex_mojo_boxarray_destroy(boxarray);
    amrex_mojo_runtime_destroy(runtime);

    return 0;
}
