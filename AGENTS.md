# Repository Guidelines

## Project Structure & Module Organization
`mojo/amrex/` contains the Mojo package exported as top-level `amrex`, with `space3d/` holding the 3D bindings and helper types. `src/capi/` contains the narrow C ABI layer backed by AMReX. `examples/Multifab/` and `examples/HeatEquation/` are the main runnable demos, including GPU and MPI variants. Tests live in `tests/capi/` and `tests/mojo/`. Keep design notes in `docs/`; treat `build/`, `.pixi/`, and `*.mojoc` as generated artifacts.

## Build, Test, and Development Commands
Use Pixi from the repo root.

- `pixi run bootstrap`: configure CMake, build the C ABI, and install the shared library plus `amrex.mojoc` into the default env.
- `pixi run configure`: refresh the `build/` tree with MPI enabled.
- `pixi run build-capi`: rebuild `amrex_mojo_capi_3d`.
- `pixi run install-amrex`: install the library and Mojo package into `.pixi/envs/default`.
- `pixi run test`: run the full local test suite.
- `pixi run test-mpi`: run MPI coverage with `mpiexec`.
- `pixi run format-mojo`: format `mojo/amrex`, `examples`, and `tests/mojo`.

Useful smoke runs: `mojo examples/Multifab/multifab.mojo` and `mojo examples/HeatEquation/heat_equation_gpu.mojo`.

## Coding Style & Naming Conventions
Follow the existing style: 4-space indentation, short functions, and `snake_case` for files, variables, and most symbols (`multifab_functional_test.mojo`, `gpu_device_id`). Keep Mojo module paths aligned with `mojo/amrex/`. Match the repo’s CMake style by using multi-line argument blocks instead of dense one-liners. Run `pixi run format-mojo` before submitting Mojo changes.

## Testing Guidelines
Add new Mojo tests under `tests/mojo/` with a `_test.mojo` suffix. Add C++ ABI coverage under `tests/capi/` and register it through CMake. At minimum, run `pixi run test` before opening a PR. If you touch MPI, GPU interop, or runtime initialization, also run `pixi run test-mpi` and one relevant example script.

## Agent-Specific Instructions
When editing Mojo code, consult the Mojo skills repo at `https://github.com/modular/skills`. Treat `mojo-syntax` as the syntax source of truth. Add `mojo-gpu-fundamentals` for GPU work and `mojo-python-interop` for Python-facing bindings or packaging.

## Commit & Pull Request Guidelines
Recent history uses short, imperative, lowercase commit subjects such as `update docs` and `add heat equation example`. Keep commits focused and avoid bundling refactors with behavior changes. PRs should include a brief summary, linked issue if applicable, the exact validation commands you ran, and any platform details that matter here (MPI stack, GPU backend, or AMReX source override). Screenshots are not expected for this repository.
