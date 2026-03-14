cmake_minimum_required(VERSION 3.24)

project(amrex_mojo LANGUAGES C CXX)

include(FetchContent)
include(CheckLanguage)
include(CTest)

option(
    AMREX_MOJO_ENABLE_AMREX
    "Link the C API against a real AMReX build."
    ON
)

option(
    AMREX_MOJO_BUILD_SHARED
    "Build the AMReX Mojo C API as a shared library."
    ON
)

option(
    AMREX_MOJO_ENABLE_MPI
    "Enable MPI support in AMReX and the Mojo bindings."
    OFF
)

set(
    AMREX_MOJO_GPU_BACKEND
    "AUTO"
    CACHE STRING
    "GPU backend for AMReX (AUTO, NONE, CUDA, or HIP)."
)
set_property(
    CACHE AMREX_MOJO_GPU_BACKEND
    PROPERTY STRINGS AUTO NONE CUDA HIP
)

set(AMREX_MOJO_AMREX_SOURCE_DIR_DEFAULT "")
set(
    AMREX_MOJO_AMREX_SOURCE_DIR
    "${AMREX_MOJO_AMREX_SOURCE_DIR_DEFAULT}"
    CACHE PATH
    "Optional path to a local AMReX source tree. Leave empty to fetch from GitHub."
)

set(
    AMREX_MOJO_AMREX_GIT_REPOSITORY
    "https://github.com/WeiqunZhang/amrex.git"
    CACHE STRING
    "Git repository used when fetching AMReX with FetchContent."
)

set(
    AMREX_MOJO_AMREX_GIT_TAG
    "external_gpu_stream"
    CACHE STRING
    "Git branch, tag, or commit used when fetching AMReX with FetchContent."
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(AMREX_MOJO_BUILD_SHARED)
    set(
        CMAKE_POSITION_INDEPENDENT_CODE
        ON
        CACHE BOOL
        "Build static libraries with position-independent code for shared linkage."
        FORCE
    )
endif()

set(AMREX_MOJO_VALID_GPU_BACKENDS AUTO NONE CUDA HIP)
if(NOT AMREX_MOJO_GPU_BACKEND IN_LIST AMREX_MOJO_VALID_GPU_BACKENDS)
    message(
        FATAL_ERROR
        "AMREX_MOJO_GPU_BACKEND='${AMREX_MOJO_GPU_BACKEND}' is invalid. Use AUTO, NONE, CUDA, or HIP."
    )
endif()

if(NOT AMREX_MOJO_ENABLE_AMREX)
    message(FATAL_ERROR "The Mojo bindings MVP requires AMReX. Configure with -DAMREX_MOJO_ENABLE_AMREX=ON.")
endif()

set(AMREX_MOJO_RESOLVED_GPU_BACKEND "${AMREX_MOJO_GPU_BACKEND}")
if(AMREX_MOJO_GPU_BACKEND STREQUAL "AUTO")
    check_language(CUDA)
    check_language(HIP)

    if(CMAKE_CUDA_COMPILER)
        set(AMREX_MOJO_RESOLVED_GPU_BACKEND "CUDA")
        if(CMAKE_HIP_COMPILER)
            message(
                STATUS
                "Detected CUDA compiler '${CMAKE_CUDA_COMPILER}' and HIP compiler '${CMAKE_HIP_COMPILER}'; selecting CUDA. Override with -DAMREX_MOJO_GPU_BACKEND=HIP or NONE to change this."
            )
        else()
            message(
                STATUS
                "Detected CUDA compiler '${CMAKE_CUDA_COMPILER}'; selecting AMReX GPU backend CUDA."
            )
        endif()
    elseif(CMAKE_HIP_COMPILER)
        set(AMREX_MOJO_RESOLVED_GPU_BACKEND "HIP")
        message(
            STATUS
            "Detected HIP compiler '${CMAKE_HIP_COMPILER}'; selecting AMReX GPU backend HIP."
        )
    else()
        set(AMREX_MOJO_RESOLVED_GPU_BACKEND "NONE")
        message(
            STATUS
            "No CUDA or HIP compiler detected; selecting AMReX GPU backend NONE."
        )
    endif()
elseif(AMREX_MOJO_GPU_BACKEND STREQUAL "CUDA")
    check_language(CUDA)
    if(NOT CMAKE_CUDA_COMPILER)
        message(
            FATAL_ERROR
            "AMREX_MOJO_GPU_BACKEND='CUDA' was requested, but no CUDA compiler was detected."
        )
    endif()
elseif(AMREX_MOJO_GPU_BACKEND STREQUAL "HIP")
    check_language(HIP)
    if(NOT CMAKE_HIP_COMPILER)
        message(
            FATAL_ERROR
            "AMREX_MOJO_GPU_BACKEND='HIP' was requested, but no HIP compiler was detected."
        )
    endif()
endif()

message(
    STATUS
    "AMReX Mojo GPU backend request='${AMREX_MOJO_GPU_BACKEND}', resolved='${AMREX_MOJO_RESOLVED_GPU_BACKEND}'."
)

if(NOT TARGET AMReX::amrex_3d AND NOT TARGET AMReX::amrex)
    set(AMReX_SPACEDIM 3 CACHE STRING "Dimension of AMReX build" FORCE)
    set(AMReX_PRECISION DOUBLE CACHE STRING "Precision of AMReX build" FORCE)
    set(AMReX_MPI ${AMREX_MOJO_ENABLE_MPI} CACHE BOOL "Enable MPI in AMReX" FORCE)
    set(AMReX_OMP OFF CACHE BOOL "Enable OpenMP in AMReX" FORCE)
    set(
        AMReX_GPU_BACKEND
        ${AMREX_MOJO_RESOLVED_GPU_BACKEND}
        CACHE STRING
        "GPU backend for AMReX"
        FORCE
    )
    set(AMReX_PARTICLES OFF CACHE BOOL "Enable AMReX particle classes" FORCE)
    set(AMReX_EB OFF CACHE BOOL "Enable AMReX embedded boundary support" FORCE)
    set(AMReX_FORTRAN OFF CACHE BOOL "Enable AMReX Fortran interfaces" FORCE)

    if(AMREX_MOJO_AMREX_SOURCE_DIR)
        if(NOT EXISTS "${AMREX_MOJO_AMREX_SOURCE_DIR}/CMakeLists.txt")
            message(
                FATAL_ERROR
                "AMREX_MOJO_AMREX_SOURCE_DIR='${AMREX_MOJO_AMREX_SOURCE_DIR}' does not contain a CMakeLists.txt."
            )
        endif()

        FetchContent_Declare(
            amrex
            SOURCE_DIR "${AMREX_MOJO_AMREX_SOURCE_DIR}"
        )
    else()
        FetchContent_Declare(
            amrex
            GIT_REPOSITORY "${AMREX_MOJO_AMREX_GIT_REPOSITORY}"
            GIT_TAG "${AMREX_MOJO_AMREX_GIT_TAG}"
            GIT_SHALLOW TRUE
        )
    endif()

    FetchContent_MakeAvailable(amrex)
endif()

add_subdirectory(src/capi)

if(BUILD_TESTING)
    add_subdirectory(tests/capi)
endif()
