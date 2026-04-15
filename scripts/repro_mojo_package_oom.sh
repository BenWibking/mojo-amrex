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

printf 'Repository: %s\n' "$repo_root"
printf 'Output: %s\n' "$out_path"
printf 'Step 1/4: configure\n'
pixi run configure

printf 'Step 2/4: build C API\n'
pixi run build-capi

printf 'Step 3/4: install native artifacts\n'
env OMPI_CC=cc OMPI_CXX=c++ cmake --install build

printf 'Step 4/4: package Mojo module\n'
set +e
pixi run mojo package mojo/amrex -o "$out_path"
status=$?
set -e

if [ "$status" -eq 0 ]; then
  echo "mojo package succeeded; the OOM did not reproduce on this machine"
  exit 0
fi

echo "mojo package failed with exit code $status"
echo "If the failure includes 'the Mojo compiler ran out of memory', the OOM reproduced successfully."
exit "$status"
