# AMReX Runtime Lifetime Options

## Problem Statement

`AmrexRuntime` currently exposes an explicit `close()` that immediately calls
`amrex_mojo_runtime_destroy`. At the same time, runtime-bound wrapper types such
as `BoxArray`, `Geometry`, `MultiFab`, `MFIter`, `GpuMFIter`, and `ParmParse`
retain `RuntimeLease` and free their C++ handles in `__del__`.

That combination creates a lifetime inversion:

1. User code constructs `AmrexRuntime`.
2. User code constructs one or more wrapper objects derived from that runtime.
3. User code calls `runtime.close()` while those wrapper objects are still live.
4. Wrapper destructors later run after the AMReX runtime has already been
   finalized.

This is unsafe because the wrapper cleanup paths assume the AMReX runtime and
its loaded library remain valid until their own destruction finishes.

Before the explicit-destroy change, `_AmrexRuntimeState.__del__` avoided this by
keeping the runtime alive until the last `RuntimeLease` disappeared. The review
feedback is effectively asking whether that should remain the architectural
model, or whether the package should move to a different ownership design.

## Current Constraints

- The wrapper layer already uses shared runtime ownership through
  `RuntimeLease`.
- Wrapper cleanup is deferred to `__del__`, not to explicit `close()` methods.
- Examples and tests now call `runtime.close()` before local wrapper values go
  out of scope.
- AMReX runtime finalization appears to be process-global enough that freeing
  wrapper resources after runtime destruction is a bad pattern.

Any safe design must make runtime teardown and wrapper teardown consistent.

## Option 1: Restore Lease-Owned Runtime Finalization

### Summary

Revert to the prior model where `_AmrexRuntimeState.__del__` performs
`amrex_mojo_runtime_destroy`, and `AmrexRuntime` itself no longer destroys the
runtime independently of outstanding leases.

### How It Works

- `AmrexRuntime` continues to act as the root constructor and entry point.
- Wrappers continue to retain `RuntimeLease`.
- The runtime stays alive until the last lease disappears.
- Wrapper destructors remain valid because they cannot outlive the shared
  runtime state they depend on.

### Pros

- Smallest code change.
- Matches the current wrapper ownership model.
- Fixes the review issue without redesigning the rest of the API.
- Preserves existing ergonomics for examples and tests.
- Keeps destruction safety local to the ownership graph instead of relying on
  caller discipline.

### Cons

- Runtime destruction is no longer explicitly timed by the caller.
- The actual AMReX teardown point remains tied to scope and reference lifetime.
- If deterministic release is a major goal, this only partially satisfies it.

### When This Is The Right Choice

This is the best fit if the goal is to safely resolve the review feedback with
minimal API churn.

## Option 2: Keep `close()`, but Defer Physical Destruction Until Last Lease

### Summary

Retain an explicit `close()` API, but change its behavior so it marks the
runtime as closed or closing rather than immediately destroying the underlying
AMReX runtime. Actual finalization still occurs only when the last
`RuntimeLease` disappears.

### How It Works

- Add state to `_AmrexRuntimeState`, such as `is_closing` or `is_closed`.
- `close()` marks the runtime as closed for future operations.
- New wrapper creation and runtime operations fail after close.
- Existing wrapper objects remain destructible because the underlying runtime is
  not physically destroyed until the final lease is dropped.

### Pros

- Preserves an explicit shutdown API.
- Prevents new work from being created after closure.
- Avoids the lifetime inversion that caused the review issue.
- Offers a clearer semantic distinction between "accepting new work" and
  "physically finalized."

### Cons

- More statefulness and more edge cases than Option 1.
- Requires careful decisions about which methods should fail after `close()`.
- The name `close()` may still imply immediate teardown even though destruction
  is deferred.

### When This Is The Right Choice

This is the best compromise if explicit shutdown is important as a public API
goal, but the package is not ready to convert every wrapper type to explicit
destruction.

## Option 3: Make `close()` Reject Outstanding Leases

### Summary

Keep immediate runtime destruction, but make `close()` fail if any dependent
wrapper objects still exist.

### How It Works

- Track the number of outstanding leases or dependent objects.
- `close()` checks that no wrappers remain live.
- If wrappers still exist, `close()` raises an error instead of destroying the
  runtime.

### Pros

- Preserves true immediate teardown semantics.
- Makes the ownership rule explicit to callers.
- Avoids silent unsafe destruction.

### Cons

- Requires reliable live-object accounting.
- Pushes destruction ordering burden onto the caller.
- Easily becomes frustrating in normal use, especially in examples and tests.
- Does not align well with current wrapper ergonomics, which rely on `__del__`.
- Makes success depend on subtle scoping details that are easy to miss.

### When This Is The Right Choice

This makes sense only if the package strongly values immediate teardown and is
comfortable enforcing strict caller discipline. That does not appear to match
the current design.

## Option 4: Convert The Entire Wrapper Layer To Explicit Destruction

### Summary

Extend the explicit-destroy model to all runtime-bound wrappers so the whole API
uses top-down, deterministic teardown instead of deferred `__del__` cleanup.

### How It Works

- `BoxArray`, `Geometry`, `MultiFab`, `MFIter`, `GpuMFIter`, `ParmParse`, and
  related types get explicit `close()` methods or explicit-destroy semantics.
- Callers must destroy wrappers before destroying `AmrexRuntime`.
- Examples and tests must be rewritten to enforce strict destruction order.

### Pros

- Architecturally consistent if explicit destruction is the desired direction.
- Gives callers deterministic control over resource release.
- Eliminates ambiguity about when cleanup happens.

### Cons

- Large API change.
- Higher burden on users.
- Easy to introduce leaks or partial-cleanup bugs during migration.
- Requires broad changes across docs, examples, tests, and likely error
  handling.
- Too large for a narrow review fix.

### When This Is The Right Choice

This is appropriate only if the project wants to deliberately shift the entire
binding layer toward explicit lifetime management as a broader design decision.

## Option 5: Introduce A Higher-Level Scoped Owner

### Summary

Create a scoped session or owner abstraction that contains the runtime and
derived wrapper objects, so user code cannot outlive the owning scope.

### How It Works

- Add a `RuntimeScope`, session, or builder-style abstraction.
- Runtime-bound objects are created through that scope.
- The scope controls destruction order and ensures wrappers die before the
  runtime.

### Pros

- Potentially the cleanest long-term ownership story.
- Can make correct teardown easy by construction.
- Reduces reliance on ad hoc caller discipline.

### Cons

- Significant redesign.
- May feel heavy for simple examples.
- Requires rethinking construction APIs and wrapper relationships.
- Too much change for the current review issue.

### When This Is The Right Choice

This is a strategic option for a future redesign, not the most practical way to
resolve the present safety issue.

## Recommendation

### Recommended Path

Adopt **Option 1** now, with **Option 2** as the only strong alternative if
retaining an explicit shutdown API is a firm requirement.

### Justification

Option 1 is the most appropriate response to the current codebase because it
matches the ownership model that already exists:

- Wrappers already retain shared runtime state through `RuntimeLease`.
- Wrappers already perform deferred cleanup in `__del__`.
- The previous implementation already encoded the safe invariant: runtime
  teardown happens after the last lease disappears.

That makes Option 1 the smallest, safest, and most coherent fix. It removes the
lifetime inversion without forcing a redesign of every wrapper type or pushing
fragile ordering requirements onto users.

Option 2 is defensible if explicit shutdown is a real product goal, but it
should be understood as a semantic split:

- `close()` stops the runtime from accepting new work.
- actual AMReX destruction still waits for the last lease.

That can work well, but it is more complex than Option 1 and needs careful API
rules around post-close behavior.

### Why The Other Options Are Not Recommended For This Fix

- Option 3 preserves immediate teardown, but only by making caller discipline a
  hard requirement in an API that is currently designed around deferred wrapper
  cleanup.
- Option 4 is coherent only as a project-wide redesign toward explicit
  destruction everywhere.
- Option 5 is attractive long-term, but it is a redesign rather than a review
  fix.

## Suggested Next Step

Use Option 1 to address the review comment and restore the safety invariant
first. If explicit shutdown still matters after that, revisit Option 2 as a
follow-up design change with separate API discussion, tests, and documentation.
