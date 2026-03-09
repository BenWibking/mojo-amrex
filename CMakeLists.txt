cmake_minimum_required(VERSION 3.24)

project(amrex_mojo LANGUAGES C CXX)

option(
    AMREX_MOJO_ENABLE_AMREX
    "Link the C API against a real AMReX build."
    OFF
)

option(
    AMREX_MOJO_BUILD_SHARED
    "Build the AMReX Mojo C API as a shared library."
    ON
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_subdirectory(src/capi)
