# `runtime_create_impl` leaks the new `runtime_state` if `amrex::Initialize` throws

**Severity: Low** (small one-time leak on an already-failing path)

## Explanation

In `runtime_create_impl` (`src/capi/init.cpp:302-316`), the not-yet-initialized
branch allocates the state object before calling into AMReX:

```cpp
auto* new_state = new amrex_mojo::detail::runtime_state{};
auto argv_storage = build_argv_storage(argc, argv);
auto argv_ptrs = build_argv_ptrs(argv_storage);
int argc_local = static_cast<int>(argv_storage.size());
char** argv_local = argv_ptrs.data();
initialize_amrex_runtime(argc_local, argv_local, use_parmparse != 0, use_device_id, device_id);
new_state->owns_initialization = true;
state = new_state;
g_runtime_state = state;
```

If `amrex::Initialize` (or `build_argv_storage`'s allocations) throws, control
jumps to the `catch` blocks at the bottom of the function, which set the last
error and return `nullptr` — `new_state` is never freed and is not yet reachable
through `g_runtime_state`. The same pattern exists for the already-initialized
branch at `init.cpp:318`, where only an `std::bad_alloc` from `new` itself could
escape (and then there is nothing to leak), so only the first branch matters.

## Proposed patch

Allocate the state only after AMReX initialization succeeds; `owns_initialization`
can be set in the initializer:

```cpp
auto argv_storage = build_argv_storage(argc, argv);
auto argv_ptrs = build_argv_ptrs(argv_storage);
int argc_local = static_cast<int>(argv_storage.size());
char** argv_local = argv_ptrs.data();
initialize_amrex_runtime(argc_local, argv_local, use_parmparse != 0, use_device_id, device_id);
auto* new_state = new amrex_mojo::detail::runtime_state{};
new_state->owns_initialization = true;
state = new_state;
g_runtime_state = state;
```

(Alternatively hold it in a `std::unique_ptr` and `release()` once registered.)
