# Associated-type return capture loses destructibility witness

Observed with:

```text
Mojo 1.0.0b2.dev2026052115 (cb8874f5)
```

Reproducer command from the repository root:

```bash
pixi run mojo issues/closures/associated_type_register_passable_capture_repro.mojo
```

Expected behavior: the program compiles. `get_value[RealTag]()` returns a
concrete `Float64`, and `Float64` should be valid to capture in a
`register_passable` closure satisfying `DevicePassable`.

Actual behavior: the compiler rejects the closure capture with a missing
`ImplicitlyDestructible.__del__` witness:

```text
failed to locate witness entry '__del__($0$)' for trait 'std::builtin::anytype::ImplicitlyDestructible'
```

Workaround: add an explicit concrete type annotation at the receiving variable:

```mojo
var dt: Float64 = get_value[RealTag]()
```

This came up in the AMReX Mojo bindings when a `ParmParse` generic query API
returned `T.value_type`; values inferred from `ParmReal.value_type` failed when
captured in `register_passable` stencil closures.
