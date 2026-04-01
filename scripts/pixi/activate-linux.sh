#!/usr/bin/env bash

prepend_ld_library_path() {
    local path="$1"

    if [ -z "$path" ] || [ ! -d "$path" ]; then
        return
    fi

    case ":${LD_LIBRARY_PATH:-}:" in
        *":$path:"*) ;;
        *)
            export LD_LIBRARY_PATH="${path}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
            ;;
    esac
}

prepend_ld_library_path "${CONDA_PREFIX}/lib"
prepend_ld_library_path "${ROCM_PATH:-}/lib"
prepend_ld_library_path "${ROCM_PATH:-}/lib64"

if command -v hipconfig >/dev/null 2>&1; then
    hip_root="$(hipconfig --path 2>/dev/null || true)"
    prepend_ld_library_path "${hip_root}/lib"
    prepend_ld_library_path "${hip_root}/lib64"
fi

prepend_ld_library_path "/opt/rocm/lib"
prepend_ld_library_path "/opt/rocm/lib64"
prepend_ld_library_path "/usr/lib64"
