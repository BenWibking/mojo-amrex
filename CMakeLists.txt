cmake_minimum_required(VERSION 3.24)

project(amrex_mojo LANGUAGES C CXX)

set(AMREX_MOJO_AMREX_SOURCE_DIR_DEFAULT "${CMAKE_CURRENT_SOURCE_DIR}/../amrex")
if(EXISTS "${AMREX_MOJO_AMREX_SOURCE_DIR_DEFAULT}/CMakeLists.txt")
    set(AMREX_MOJO_ENABLE_AMREX_DEFAULT ON)
else()
    set(AMREX_MOJO_ENABLE_AMREX_DEFAULT OFF)
endif()

option(
    AMREX_MOJO_ENABLE_AMREX
    "Link the C API against a real AMReX build."
    ${AMREX_MOJO_ENABLE_AMREX_DEFAULT}
)

option(
    AMREX_MOJO_BUILD_SHARED
    "Build the AMReX Mojo C API as a shared library."
    ON
)

set(
    AMREX_MOJO_AMREX_SOURCE_DIR
    "${AMREX_MOJO_AMREX_SOURCE_DIR_DEFAULT}"
    CACHE PATH
    "Path to the AMReX source tree used for the Mojo bindings."
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_subdirectory(src/capi)
