#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v pixi >/dev/null 2>&1; then
  echo "error: pixi is required but was not found in PATH" >&2
  exit 1
fi

out_path="${1:-$repo_root/.tmp/amrex-oom-repro/amrex.mojopkg}"
out_dir="$(dirname "$out_path")"
mkdir -p "$out_dir"
limited_out_path="${out_dir}/$(basename "${out_path%.*}")-ulimit-8g.mojopkg"

run_package() {
  local label="$1"
  local output_path="$2"
  shift 2

  printf 'Packaging (%s) -> %s\n' "$label" "$output_path"
  set +e
  "$@"
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "mojo package succeeded for: $label"
  else
    echo "mojo package failed for: $label (exit code $status)"
  fi

  return "$status"
}

printf 'Repository: %s\n' "$repo_root"
printf 'Output: %s\n' "$out_path"
printf 'Limited output: %s\n' "$limited_out_path"
printf 'Step 1/5: configure\n'
pixi run configure

printf 'Step 2/5: build C API\n'
pixi run build-capi

printf 'Step 3/5: install native artifacts\n'
env OMPI_CC=cc OMPI_CXX=c++ cmake --install build

printf 'Step 4/5: package Mojo module with current limits\n'
unlimited_status=0
run_package \
  "current limits" \
  "$out_path" \
  pixi run mojo package mojo/amrex -o "$out_path" || unlimited_status=$?

printf 'Step 5/5: package Mojo module with ulimit -v 8388608\n'
limited_status=0
run_package \
  "ulimit -v 8388608" \
  "$limited_out_path" \
  bash -lc "ulimit -v 8388608 && exec pixi run mojo package mojo/amrex -o \"$limited_out_path\"" || limited_status=$?

echo
echo "Summary:"
echo "  current limits exit code: $unlimited_status"
echo "  ulimit -v 8388608 exit code: $limited_status"
echo "If only the 8 GiB-limited run shows 'the Mojo compiler ran out of memory', RLIMIT_AS is likely the trigger."

if [ "$limited_status" -ne 0 ]; then
  exit "$limited_status"
fi

exit "$unlimited_status"
