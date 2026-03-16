# Code Audit Findings

Validation note: `pixi run test` and `pixi run test-mpi` both passed during this audit.

Focused repro note: I also ran small live repros against the built package. Those confirmed:
- `mf.sum(1)` on a one-component `MultiFab` returns `0.0` instead of raising.
- `mf.tile_box(0).nodal` can disagree with `mf.tile(0).tile_box.nodal`.
- `mf.plus(1.0, 0, 1, intvect3d(1, 1, 1))` currently fails even though the ghost width is isotropic.

## Issue 1: Missing runtime-state compatibility checks allow cross-runtime handle mixing

**Severity:** High

**Issue summary:**  
Several C API entry points accept multiple opaque AMReX handles but only validate nullness, not that the handles were created by the same live `runtime_state`. Examples include [src/capi/distmap.cpp](src/capi/distmap.cpp#L4), [src/capi/multifab.cpp](src/capi/multifab.cpp#L643), [src/capi/multifab.cpp](src/capi/multifab.cpp#L128), [src/capi/multifab.cpp](src/capi/multifab.cpp#L1482), [src/capi/multifab.cpp](src/capi/multifab.cpp#L1545), and [src/capi/multifab.cpp](src/capi/multifab.cpp#L1625). That means a caller can mix objects originating from different `AmrexRuntime(path=...)` instances or even different copies of the C ABI dylib. The code then passes foreign heap objects into the wrong library instance, which is undefined behavior and can surface as silent corruption, crashes, or misleading `last_error` state.

**Proposed code patch:**

```diff
diff --git a/src/capi/capi_internal.H b/src/capi/capi_internal.H
@@
     runtime_state* retain_runtime(runtime_state* state) noexcept;
     void release_runtime(runtime_state* state) noexcept;
+
+    inline amrex_mojo_status_code_t require_same_runtime_state(
+        const runtime_state* lhs,
+        const runtime_state* rhs,
+        const char* context
+    ) noexcept
+    {
+        if (lhs == nullptr || rhs == nullptr || lhs != rhs) {
+            return set_last_error(
+                AMREX_MOJO_STATUS_INVALID_ARGUMENT,
+                std::string(context)
+                    + " requires handles created from the same live AMReX runtime."
+            );
+        }
+        return AMREX_MOJO_STATUS_OK;
+    }
diff --git a/src/capi/distmap.cpp b/src/capi/distmap.cpp
@@
     if (runtime == nullptr || runtime->state == nullptr || boxarray == nullptr) {
         amrex_mojo::detail::set_last_error(
             AMREX_MOJO_STATUS_INVALID_ARGUMENT,
             "distmap_create_from_boxarray requires a live runtime and a non-null boxarray."
         );
         return nullptr;
     }
+
+    if (
+        amrex_mojo::detail::require_same_runtime_state(
+            runtime->state,
+            boxarray->state,
+            "distmap_create_from_boxarray"
+        ) != AMREX_MOJO_STATUS_OK
+    ) {
+        return nullptr;
+    }
diff --git a/src/capi/multifab.cpp b/src/capi/multifab.cpp
@@
     if (runtime == nullptr || runtime->state == nullptr || boxarray == nullptr || distmap == nullptr) {
         amrex_mojo::detail::set_last_error(
             AMREX_MOJO_STATUS_INVALID_ARGUMENT,
             "multifab_create requires a live runtime, boxarray, and distmap."
         );
         return nullptr;
     }
+
+    if (
+        amrex_mojo::detail::require_same_runtime_state(
+            runtime->state,
+            boxarray->state,
+            "multifab_create"
+        ) != AMREX_MOJO_STATUS_OK ||
+        amrex_mojo::detail::require_same_runtime_state(
+            runtime->state,
+            distmap->state,
+            "multifab_create"
+        ) != AMREX_MOJO_STATUS_OK
+    ) {
+        return nullptr;
+    }
@@
     if (!require_live_multifab(multifab, "multifab access by MFIter")) {
         return nullptr;
     }
+
+    if (
+        amrex_mojo::detail::require_same_runtime_state(
+            multifab->state,
+            mfiter->state,
+            "multifab access by MFIter"
+        ) != AMREX_MOJO_STATUS_OK
+    ) {
+        return nullptr;
+    }
@@
     if (
         !require_live_multifab(dst_multifab, "multifab_copy") ||
         !require_live_multifab(src_multifab, "multifab_copy")
     ) {
         return amrex_mojo::detail::set_last_error(
             AMREX_MOJO_STATUS_INVALID_ARGUMENT,
             "multifab_copy requires non-null source and destination multifabs."
         );
     }
+
+    if (
+        amrex_mojo::detail::require_same_runtime_state(
+            dst_multifab->state,
+            src_multifab->state,
+            "multifab_copy"
+        ) != AMREX_MOJO_STATUS_OK
+    ) {
+        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
+    }
@@
     if (
         !require_live_multifab(dst_multifab, "multifab_parallel_copy") ||
         !require_live_multifab(src_multifab, "multifab_parallel_copy") ||
         geometry == nullptr
     ) {
         return amrex_mojo::detail::set_last_error(
             AMREX_MOJO_STATUS_INVALID_ARGUMENT,
             "multifab_parallel_copy requires non-null source, destination, and geometry."
         );
     }
+
+    if (
+        amrex_mojo::detail::require_same_runtime_state(
+            dst_multifab->state,
+            src_multifab->state,
+            "multifab_parallel_copy"
+        ) != AMREX_MOJO_STATUS_OK ||
+        amrex_mojo::detail::require_same_runtime_state(
+            dst_multifab->state,
+            geometry->state,
+            "multifab_parallel_copy"
+        ) != AMREX_MOJO_STATUS_OK
+    ) {
+        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
+    }
@@
     if (!require_live_multifab(multifab, "multifab_fill_boundary") || geometry == nullptr) {
         return amrex_mojo::detail::set_last_error(
             AMREX_MOJO_STATUS_INVALID_ARGUMENT,
             "multifab_fill_boundary requires a non-null multifab and geometry."
         );
     }
+
+    if (
+        amrex_mojo::detail::require_same_runtime_state(
+            multifab->state,
+            geometry->state,
+            "multifab_fill_boundary"
+        ) != AMREX_MOJO_STATUS_OK
+    ) {
+        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
+    }
@@
     if (!require_live_multifab(multifab, "write_single_level_plotfile") || geometry == nullptr || plotfile == nullptr ||
         std::string(plotfile).empty()) {
         return amrex_mojo::detail::set_last_error(
             AMREX_MOJO_STATUS_INVALID_ARGUMENT,
             "write_single_level_plotfile requires non-null multifab, geometry, and plotfile path."
         );
     }
+
+    if (
+        amrex_mojo::detail::require_same_runtime_state(
+            multifab->state,
+            geometry->state,
+            "write_single_level_plotfile"
+        ) != AMREX_MOJO_STATUS_OK
+    ) {
+        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
+    }
```

## Issue 2: `release_runtime` can race with `runtime_create_impl` and hand out a runtime during finalization

**Severity:** Medium

**Issue summary:**  
[src/capi/init.cpp](src/capi/init.cpp#L332) clears `g_runtime_state` while holding `g_runtime_mutex`, but it calls `amrex::Finalize()` only after releasing the lock. Meanwhile [src/capi/init.cpp](src/capi/init.cpp#L247) acquires the same mutex to decide whether to reuse `g_runtime_state` or create a new one. A concurrent destroy/create interleaving can therefore create a fresh `runtime_state` after `g_runtime_state` is cleared but before `Finalize()` runs, leaving the new handle attached to a runtime that is about to be finalized underneath it.

**Proposed code patch:**

```diff
diff --git a/src/capi/init.cpp b/src/capi/init.cpp
@@
     void release_runtime(runtime_state* state) noexcept
     {
         if (state == nullptr) {
             return;
         }
 
-        bool should_delete = false;
         bool should_finalize = false;
-        {
-            std::lock_guard<std::mutex> lock(g_runtime_mutex);
-            const auto previous = state->ref_count.fetch_sub(1, std::memory_order_acq_rel);
-            if (previous == 1) {
-                should_delete = true;
-                should_finalize = state->owns_initialization;
-                if (g_runtime_state == state) {
-                    g_runtime_state = nullptr;
-                }
-            }
-        }
-
-        if (!should_delete) {
-            return;
-        }
-
-        if (should_finalize) {
-            try {
-                if (amrex::Initialized()) {
-                    amrex::Finalize();
-                }
-            } catch (...) {
-            }
-        }
+        {
+            std::unique_lock<std::mutex> lock(g_runtime_mutex);
+            const auto previous = state->ref_count.fetch_sub(1, std::memory_order_acq_rel);
+            if (previous != 1) {
+                return;
+            }
 
-        delete state;
+            should_finalize = state->owns_initialization;
+            if (g_runtime_state == state) {
+                g_runtime_state = nullptr;
+            }
+
+            if (should_finalize) {
+                try {
+                    if (amrex::Initialized()) {
+                        amrex::Finalize();
+                    }
+                } catch (...) {
+                }
+            }
+        }
+
+        delete state;
     }
```

## Issue 3: `MultiFab` reduction methods silently return `0.0` for invalid component indices

**Severity:** Medium

**Issue summary:**  
The public Mojo reduction methods [mojo/amrex/space3d/multifab.mojo](/Users/benwibking/amrex_codes/mojo-amrex/mojo/amrex/space3d/multifab.mojo#L203) and [mojo/amrex/space3d/multifab.mojo](/Users/benwibking/amrex_codes/mojo-amrex/mojo/amrex/space3d/multifab.mojo#L554) directly return the scalar value from the C API. But the corresponding C functions [src/capi/multifab.cpp](/Users/benwibking/amrex_codes/mojo-amrex/src/capi/multifab.cpp#L1295) through [src/capi/multifab.cpp](src/capi/multifab.cpp#L1369) signal invalid component indices only by setting `last_error` and returning `0.0`. Because the Mojo layer never checks for that error, user code gets a plausible numeric result instead of an exception. This was reproduced against the live build with `mf.sum(1)` on a one-component `MultiFab`, which printed `0.0`.

**Proposed code patch:**

```diff
diff --git a/mojo/amrex/space3d/multifab.mojo b/mojo/amrex/space3d/multifab.mojo
@@
+def _require_component_index(
+    comp: Int, ncomp: Int, context: StringLiteral
+) raises:
+    if comp < 0 or comp >= ncomp:
+        raise Error(
+            String(context)
+            + " requires a component index in [0, "
+            + String.write(ncomp)
+            + ")."
+        )
@@
     def min(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFab.min")
         return multifab_min(self.runtime[].lib, handle, comp)
@@
     def max(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFab.max")
         return multifab_max(self.runtime[].lib, handle, comp)
@@
     def sum(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFab.sum")
         return multifab_sum(self.runtime[].lib, handle, comp)
@@
     def norm0(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFab.norm0")
         return multifab_norm0(self.runtime[].lib, handle, comp)
@@
     def norm1(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFab.norm1")
         return multifab_norm1(self.runtime[].lib, handle, comp)
@@
     def norm2(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFab.norm2")
         return multifab_norm2(self.runtime[].lib, handle, comp)
@@
     def min(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFabF32.min")
         return multifab_min(self.runtime[].lib, handle, comp)
@@
     def max(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFabF32.max")
         return multifab_max(self.runtime[].lib, handle, comp)
@@
     def sum(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFabF32.sum")
         return multifab_sum(self.runtime[].lib, handle, comp)
@@
     def norm0(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFabF32.norm0")
         return multifab_norm0(self.runtime[].lib, handle, comp)
@@
     def norm1(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFabF32.norm1")
         return multifab_norm1(self.runtime[].lib, handle, comp)
@@
     def norm2(ref self, comp: Int) raises -> Float64:
         var handle = self._handle()
+        _require_component_index(comp, self.ncomp(), "MultiFabF32.norm2")
         return multifab_norm2(self.runtime[].lib, handle, comp)
```

## Issue 4: `tile(tile_index)` drops nodal metadata and misreports nodal boxes as cell-centered

**Severity:** Medium

**Issue summary:**  
The `tile(tile_index)` and `for_each_tile(...)` paths build `TileF64View`/`TileF32View` from [mojo/amrex/ffi.mojo](/Users/benwibking/amrex_codes/mojo-amrex/mojo/amrex/ffi.mojo#L901) through [mojo/amrex/ffi.mojo](/Users/benwibking/amrex_codes/mojo-amrex/mojo/amrex/ffi.mojo#L1088). Those helpers reconstruct `tile_box` and `valid_box` with `box_from_bounds(...)`, which hardcodes `nodal=(0,0,0)`. The C metadata function they call does not return nodal flags, so any nodal multifab viewed through `tile(tile_index)` is silently converted to a cell-centered box. This was reproduced against the live build: `mf.tile_box(0).nodal` reported `1 0 0`, while `mf.tile(0).tile_box.nodal` reported `0 0 0`.

The `tile(mfi)` path does not have this bug because it uses `mfi.tilebox()` and `mfi.validbox()`, which preserve nodal metadata. That makes the two public access paths observably inconsistent.

**Proposed code patch:**

```diff
diff --git a/mojo/amrex/ffi.mojo b/mojo/amrex/ffi.mojo
@@
     return TileF64View[owner_origin](
-        tile_box=box_from_bounds(tile_lo, tile_hi),
-        valid_box=box_from_bounds(valid_lo, valid_hi),
+        tile_box=multifab_tile_box(lib, multifab, tile_index),
+        valid_box=multifab_valid_box(lib, multifab, tile_index),
         array_view=array_view.copy(),
     )
@@
     return TileF64View[MutAnyOrigin](
-        tile_box=box_from_bounds(tile_lo, tile_hi),
-        valid_box=box_from_bounds(valid_lo, valid_hi),
+        tile_box=multifab_tile_box(lib, multifab, tile_index),
+        valid_box=multifab_valid_box(lib, multifab, tile_index),
         array_view=array_view.copy(),
     )
@@
     return TileF32View[owner_origin](
-        tile_box=box_from_bounds(tile_lo, tile_hi),
-        valid_box=box_from_bounds(valid_lo, valid_hi),
+        tile_box=multifab_tile_box(lib, multifab, tile_index),
+        valid_box=multifab_valid_box(lib, multifab, tile_index),
         array_view=array_view.copy(),
     )
@@
     return TileF32View[MutAnyOrigin](
-        tile_box=box_from_bounds(tile_lo, tile_hi),
-        valid_box=box_from_bounds(valid_lo, valid_hi),
+        tile_box=multifab_tile_box(lib, multifab, tile_index),
+        valid_box=multifab_valid_box(lib, multifab, tile_index),
         array_view=array_view.copy(),
     )
```

## Issue 5: Explicit nonzero ghost widths for `plus`/`mult` are rejected even when isotropic

**Severity:** Medium

**Issue summary:**  
The public `plus`/`mult` APIs advertise an `IntVect3D` `ngrow` argument, and the C layer explicitly says it supports isotropic ghost widths only. But in the live build, an explicitly isotropic call like `mf.plus(1.0, 0, 1, intvect3d(1, 1, 1))` fails with `multifab_plus currently requires isotropic ghost widths.` even though the argument is already isotropic. The bug is reproducible through the public Mojo API and blocks any non-default ghost-width use for [mojo/amrex/space3d/multifab.mojo](/Users/benwibking/amrex_codes/mojo-amrex/mojo/amrex/space3d/multifab.mojo#L228) and [mojo/amrex/space3d/multifab.mojo](/Users/benwibking/amrex_codes/mojo-amrex/mojo/amrex/space3d/multifab.mojo#L578).

The current C implementation in [src/capi/multifab.cpp](/Users/benwibking/amrex_codes/mojo-amrex/src/capi/multifab.cpp#L1373) and [src/capi/multifab.cpp](/Users/benwibking/amrex_codes/mojo-amrex/src/capi/multifab.cpp#L1426) already reduces the vector to a scalar `ngrow`, so the simplest robust fix is to expose scalar C ABI entry points and stop depending on the current vector-by-value path for these methods.

**Proposed code patch:**

```diff
diff --git a/src/capi/amrex_mojo_capi.h b/src/capi/amrex_mojo_capi.h
@@
+amrex_mojo_status_code_t amrex_mojo_multifab_plus_scalar(
+    amrex_mojo_multifab_t* multifab,
+    double value,
+    int32_t start_comp,
+    int32_t ncomp,
+    int32_t ngrow
+);
+amrex_mojo_status_code_t amrex_mojo_multifab_mult_scalar(
+    amrex_mojo_multifab_t* multifab,
+    double value,
+    int32_t start_comp,
+    int32_t ncomp,
+    int32_t ngrow
+);
diff --git a/src/capi/multifab.cpp b/src/capi/multifab.cpp
@@
+extern "C" amrex_mojo_status_code_t
+amrex_mojo_multifab_plus_scalar(
+    amrex_mojo_multifab_t* multifab,
+    double value,
+    int32_t start_comp,
+    int32_t ncomp,
+    int32_t ngrow
+)
+{
+    if (!require_live_multifab(multifab, "multifab_plus")) {
+        return amrex_mojo::detail::set_last_error(
+            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
+            "multifab_plus requires a non-null multifab."
+        );
+    }
+
+    const auto valid = visit_multifab(
+        multifab,
+        [&](const auto& value_ref) {
+            return validate_component_range(value_ref, start_comp, ncomp);
+        }
+    );
+    if (valid != AMREX_MOJO_STATUS_OK) {
+        return AMREX_MOJO_STATUS_INVALID_ARGUMENT;
+    }
+
+    if (ngrow < 0) {
+        return amrex_mojo::detail::set_last_error(
+            AMREX_MOJO_STATUS_INVALID_ARGUMENT,
+            "multifab_plus requires ngrow >= 0."
+        );
+    }
+
+    try {
+        visit_multifab(
+            multifab,
+            [&](auto& value_ref) {
+                if (!value_ref.nGrowVect().allGE(ngrow)) {
+                    throw std::invalid_argument(
+                        "multifab_plus requested more ghost cells than the MultiFab owns."
+                    );
+                }
+                using value_type = typename std::decay_t<decltype(value_ref)>::value_type;
+                value_ref.plus(static_cast<value_type>(value), start_comp, ncomp, ngrow);
+            }
+        );
+        amrex_mojo::detail::clear_last_error();
+        return AMREX_MOJO_STATUS_OK;
+    } catch (const std::exception& ex) {
+        return amrex_mojo::detail::set_last_error(AMREX_MOJO_STATUS_INVALID_ARGUMENT, ex.what());
+    }
+}
+
+extern "C" amrex_mojo_status_code_t
+amrex_mojo_multifab_mult_scalar(
+    amrex_mojo_multifab_t* multifab,
+    double value,
+    int32_t start_comp,
+    int32_t ncomp,
+    int32_t ngrow
+)
+{
+    // same structure as amrex_mojo_multifab_plus_scalar, but call value_ref.mult(...)
+}
diff --git a/mojo/amrex/ffi.mojo b/mojo/amrex/ffi.mojo
@@
 def multifab_plus(
     ref lib: OwnedDLHandle,
     multifab: MultiFabHandle,
     value: Float64,
     start_comp: Int,
     ncomp: Int,
     ngrow: IntVect3D,
 ) raises -> Int:
+    if ngrow.x != ngrow.y or ngrow.x != ngrow.z:
+        raise Error("multifab_plus currently requires isotropic ghost widths.")
     return Int(
-        lib.call["amrex_mojo_multifab_plus", c_int](
+        lib.call["amrex_mojo_multifab_plus_scalar", c_int](
             multifab,
             c_double(value),
             c_int(start_comp),
             c_int(ncomp),
-            ngrow,
+            ngrow.x,
         )
     )
@@
 def multifab_mult(
     ref lib: OwnedDLHandle,
     multifab: MultiFabHandle,
     value: Float64,
     start_comp: Int,
     ncomp: Int,
     ngrow: IntVect3D,
 ) raises -> Int:
+    if ngrow.x != ngrow.y or ngrow.x != ngrow.z:
+        raise Error("multifab_mult currently requires isotropic ghost widths.")
     return Int(
-        lib.call["amrex_mojo_multifab_mult", c_int](
+        lib.call["amrex_mojo_multifab_mult_scalar", c_int](
             multifab,
             c_double(value),
             c_int(start_comp),
             c_int(ncomp),
-            ngrow,
+            ngrow.x,
         )
     )
```
