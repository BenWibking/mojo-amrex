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
