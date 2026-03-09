set(
    AMREX_MOJO_CAPI_SOURCES
    error.cpp
    init.cpp
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

if(AMREX_MOJO_ENABLE_AMREX)
    find_package(AMReX CONFIG REQUIRED)

    if(TARGET AMReX::amrex_3d)
        target_link_libraries(amrex_mojo_capi_3d PUBLIC AMReX::amrex_3d)
    elseif(TARGET AMReX::amrex)
        target_link_libraries(amrex_mojo_capi_3d PUBLIC AMReX::amrex)
    else()
        message(FATAL_ERROR "No compatible AMReX target was found.")
    endif()

    target_compile_definitions(amrex_mojo_capi_3d PRIVATE AMREX_MOJO_ENABLE_AMREX=1)
endif()

install(
    TARGETS amrex_mojo_capi_3d
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES amrex_mojo_capi.h DESTINATION include)
