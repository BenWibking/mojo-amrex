set(
    AMREX_MOJO_CAPI_SOURCES
    error.cpp
    init.cpp
    gpu.cpp
    boxarray.cpp
    distmap.cpp
    geometry.cpp
    mfiter.cpp
    multifab.cpp
    parmparse.cpp
)

if(AMREX_MOJO_RESOLVED_GPU_BACKEND STREQUAL "CUDA")
    set_source_files_properties(
        ${AMREX_MOJO_CAPI_SOURCES}
        PROPERTIES
            LANGUAGE CUDA
    )
elseif(AMREX_MOJO_RESOLVED_GPU_BACKEND STREQUAL "HIP")
    set_source_files_properties(
        ${AMREX_MOJO_CAPI_SOURCES}
        PROPERTIES
            LANGUAGE HIP
    )
endif()

if(AMREX_MOJO_BUILD_SHARED)
    add_library(amrex_mojo_capi_3d SHARED ${AMREX_MOJO_CAPI_SOURCES})
else()
    add_library(amrex_mojo_capi_3d STATIC ${AMREX_MOJO_CAPI_SOURCES})
endif()

target_include_directories(
    amrex_mojo_capi_3d
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<INSTALL_INTERFACE:include>
)

target_compile_features(amrex_mojo_capi_3d PUBLIC cxx_std_17)

if(AMREX_MOJO_RESOLVED_GPU_BACKEND STREQUAL "CUDA")
    set_target_properties(
        amrex_mojo_capi_3d
        PROPERTIES
            CUDA_STANDARD 17
            CUDA_STANDARD_REQUIRED ON
            CUDA_SEPARABLE_COMPILATION ON
            CUDA_RESOLVE_DEVICE_SYMBOLS ON
    )
elseif(AMREX_MOJO_RESOLVED_GPU_BACKEND STREQUAL "HIP")
    set_target_properties(
        amrex_mojo_capi_3d
        PROPERTIES
            HIP_STANDARD 17
            HIP_STANDARD_REQUIRED ON
    )
endif()

if(TARGET AMReX::amrex_3d)
    target_link_libraries(amrex_mojo_capi_3d PUBLIC AMReX::amrex_3d)
elseif(TARGET AMReX::amrex)
    target_link_libraries(amrex_mojo_capi_3d PUBLIC AMReX::amrex)
else()
    message(FATAL_ERROR "No compatible AMReX target was found.")
endif()

# Keep the active pixi env copy in sync with the build tree so bare `mojo`
# runs do not pick up a stale installed dylib after local rebuilds.
if(CMAKE_INSTALL_PREFIX)
    set(AMREX_MOJO_ENV_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")
    add_custom_command(
        TARGET amrex_mojo_capi_3d
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "${AMREX_MOJO_ENV_LIB_DIR}"
        COMMAND
            ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:amrex_mojo_capi_3d>
            "${AMREX_MOJO_ENV_LIB_DIR}/$<TARGET_FILE_NAME:amrex_mojo_capi_3d>"
        VERBATIM
    )
endif()

install(
    TARGETS amrex_mojo_capi_3d
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES amrex_mojo_capi.h DESTINATION include)
