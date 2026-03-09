set(
    AMREX_MOJO_CAPI_SOURCES
    error.cpp
    init.cpp
    boxarray.cpp
    distmap.cpp
    geometry.cpp
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

if(NOT AMREX_MOJO_ENABLE_AMREX)
    message(FATAL_ERROR "The Mojo bindings MVP requires AMReX. Configure with -DAMREX_MOJO_ENABLE_AMREX=ON.")
endif()

if(NOT TARGET AMReX::amrex_3d AND NOT TARGET AMReX::amrex)
    if(EXISTS "${AMREX_MOJO_AMREX_SOURCE_DIR}/CMakeLists.txt")
        set(AMReX_SPACEDIM 3 CACHE STRING "Dimension of AMReX build" FORCE)
        set(AMReX_PRECISION DOUBLE CACHE STRING "Precision of AMReX build" FORCE)
        set(AMReX_MPI OFF CACHE BOOL "Enable MPI in AMReX" FORCE)
        set(AMReX_OMP OFF CACHE BOOL "Enable OpenMP in AMReX" FORCE)
        set(AMReX_GPU_BACKEND NONE CACHE STRING "GPU backend for AMReX" FORCE)
        set(AMReX_PARTICLES OFF CACHE BOOL "Enable AMReX particle classes" FORCE)
        set(AMReX_EB OFF CACHE BOOL "Enable AMReX embedded boundary support" FORCE)
        set(AMReX_FORTRAN OFF CACHE BOOL "Enable AMReX Fortran interfaces" FORCE)
        add_subdirectory("${AMREX_MOJO_AMREX_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/_deps/amrex" EXCLUDE_FROM_ALL)
    else()
        find_package(AMReX CONFIG REQUIRED)
    endif()
endif()

if(TARGET AMReX::amrex_3d)
    target_link_libraries(amrex_mojo_capi_3d PUBLIC AMReX::amrex_3d)
elseif(TARGET AMReX::amrex)
    target_link_libraries(amrex_mojo_capi_3d PUBLIC AMReX::amrex)
else()
    message(FATAL_ERROR "No compatible AMReX target was found.")
endif()

install(
    TARGETS amrex_mojo_capi_3d
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES amrex_mojo_capi.h DESTINATION include)
