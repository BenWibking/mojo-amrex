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
    "https://github.com/AMReX-Codes/amrex.git"
    CACHE STRING
    "Git repository used when fetching AMReX with FetchContent."
)

set(
    AMREX_MOJO_AMREX_GIT_TAG
    "4039a8e99f94e6fa0639372fb82e365856cf07b3"
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

if(
    (AMREX_MOJO_GPU_BACKEND STREQUAL "AUTO" OR AMREX_MOJO_GPU_BACKEND STREQUAL "HIP")
    AND (NOT DEFINED AMReX_AMD_ARCH OR AMReX_AMD_ARCH STREQUAL "")
)
    find_program(AMREX_MOJO_ROCMINFO_EXECUTABLE NAMES rocminfo)
    if(AMREX_MOJO_ROCMINFO_EXECUTABLE)
        execute_process(
            COMMAND "${AMREX_MOJO_ROCMINFO_EXECUTABLE}"
            OUTPUT_VARIABLE AMREX_MOJO_ROCMINFO_STDOUT
            ERROR_VARIABLE AMREX_MOJO_ROCMINFO_STDERR
            RESULT_VARIABLE AMREX_MOJO_ROCMINFO_RESULT
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_STRIP_TRAILING_WHITESPACE
        )
        set(
            AMREX_MOJO_ROCMINFO_TEXT
            "${AMREX_MOJO_ROCMINFO_STDOUT}\n${AMREX_MOJO_ROCMINFO_STDERR}"
        )
        string(
            REGEX MATCHALL
            "gfx[0-9][0-9][0-9A-Za-z]+"
            AMREX_MOJO_DETECTED_HIP_ARCHES
            "${AMREX_MOJO_ROCMINFO_TEXT}"
        )
        list(REMOVE_DUPLICATES AMREX_MOJO_DETECTED_HIP_ARCHES)
        list(LENGTH AMREX_MOJO_DETECTED_HIP_ARCHES AMREX_MOJO_DETECTED_HIP_ARCH_COUNT)
        if(AMREX_MOJO_DETECTED_HIP_ARCH_COUNT GREATER 0)
            list(GET AMREX_MOJO_DETECTED_HIP_ARCHES 0 AMREX_MOJO_DETECTED_HIP_ARCH)
            set(
                AMReX_AMD_ARCH
                "${AMREX_MOJO_DETECTED_HIP_ARCH}"
                CACHE STRING
                "AMD GPU architecture target passed to AMReX for HIP builds."
                FORCE
            )
            message(
                STATUS
                "Autodetected AMReX_AMD_ARCH='${AMReX_AMD_ARCH}' from rocminfo."
            )
            if(AMREX_MOJO_DETECTED_HIP_ARCH_COUNT GREATER 1)
                message(
                    STATUS
                    "rocminfo reported multiple AMD GPU architectures (${AMREX_MOJO_DETECTED_HIP_ARCHES}); using '${AMReX_AMD_ARCH}'. Override with -DAMReX_AMD_ARCH=<gfx*> if needed."
                )
            endif()
        elseif(NOT AMREX_MOJO_ROCMINFO_RESULT EQUAL 0)
            message(
                STATUS
                "rocminfo did not report a usable AMD GPU architecture (exit code ${AMREX_MOJO_ROCMINFO_RESULT}); HIP autodetection remains disabled."
            )
        endif()
    endif()
endif()

set(AMREX_MOJO_HIP_ARCH_IS_CONFIGURED OFF)
if(DEFINED AMReX_AMD_ARCH AND NOT AMReX_AMD_ARCH STREQUAL "")
    set(AMREX_MOJO_HIP_ARCH_IS_CONFIGURED ON)
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
    elseif(CMAKE_HIP_COMPILER AND AMREX_MOJO_HIP_ARCH_IS_CONFIGURED)
        set(AMREX_MOJO_RESOLVED_GPU_BACKEND "HIP")
        message(
            STATUS
            "Detected HIP compiler '${CMAKE_HIP_COMPILER}'; selecting AMReX GPU backend HIP."
        )
    elseif(CMAKE_HIP_COMPILER)
        set(AMREX_MOJO_RESOLVED_GPU_BACKEND "NONE")
        message(
            STATUS
            "Detected HIP compiler '${CMAKE_HIP_COMPILER}' but AMReX requires -DAMReX_AMD_ARCH=<gfx*> for HIP builds; selecting AMReX GPU backend NONE."
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
    elseif(NOT AMREX_MOJO_HIP_ARCH_IS_CONFIGURED)
        message(
            FATAL_ERROR
            "AMREX_MOJO_GPU_BACKEND='HIP' was requested, but AMReX_AMD_ARCH is not set. Configure with -DAMReX_AMD_ARCH=<gfx*>."
        )
    endif()
endif()

message(
    STATUS
    "AMReX Mojo GPU backend request='${AMREX_MOJO_GPU_BACKEND}', resolved='${AMREX_MOJO_RESOLVED_GPU_BACKEND}'."
)

if(AMREX_MOJO_RESOLVED_GPU_BACKEND STREQUAL "CUDA" OR AMREX_MOJO_RESOLVED_GPU_BACKEND STREQUAL "HIP")
    set(AMREX_MOJO_HAS_COMPILED_GPU_BACKEND True)
else()
    set(AMREX_MOJO_HAS_COMPILED_GPU_BACKEND False)
endif()

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/mojo/amrex/build_config.mojo.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/mojo/amrex/build_config.mojo"
    @ONLY
)

if(AMREX_MOJO_RESOLVED_GPU_BACKEND STREQUAL "CUDA")
    enable_language(CUDA)
elseif(AMREX_MOJO_RESOLVED_GPU_BACKEND STREQUAL "HIP")
    enable_language(HIP)

    if(NOT DEFINED hip_DIR OR hip_DIR STREQUAL "")
        get_filename_component(AMREX_MOJO_HIP_COMPILER_BIN_DIR "${CMAKE_HIP_COMPILER}" DIRECTORY)
        get_filename_component(AMREX_MOJO_HIP_LLVM_DIR "${AMREX_MOJO_HIP_COMPILER_BIN_DIR}" DIRECTORY)
        get_filename_component(AMREX_MOJO_HIP_LIB_DIR "${AMREX_MOJO_HIP_LLVM_DIR}" DIRECTORY)
        get_filename_component(AMREX_MOJO_HIP_ROOT_DIR "${AMREX_MOJO_HIP_LIB_DIR}" DIRECTORY)
        set(AMREX_MOJO_HIP_CONFIG_DIR "${AMREX_MOJO_HIP_ROOT_DIR}/lib/cmake/hip")
        if(EXISTS "${AMREX_MOJO_HIP_CONFIG_DIR}/hip-config.cmake")
            list(PREPEND CMAKE_PREFIX_PATH "${AMREX_MOJO_HIP_ROOT_DIR}" "${AMREX_MOJO_HIP_ROOT_DIR}/lib/cmake")
            set(
                hip_DIR
                "${AMREX_MOJO_HIP_CONFIG_DIR}"
                CACHE PATH
                "Path to the HIP CMake package."
                FORCE
            )
            message(
                STATUS
                "Inferred hip_DIR='${hip_DIR}' from CMAKE_HIP_COMPILER."
            )
        endif()
    endif()
endif()

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
        )
    endif()

    FetchContent_MakeAvailable(amrex)
endif()

add_subdirectory(src/capi)

if(BUILD_TESTING)
    add_subdirectory(tests/capi)
endif()
