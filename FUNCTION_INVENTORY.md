# Function Review Inventory

ABOUTME: Inventory of all functions in the mojo-amrex codebase for the manual bug review.
ABOUTME: Each function is checked off after being read and reviewed; findings are filed in issues/*.md.

Scope: `mojo/amrex/`, `src/capi/`, `examples/`, `tests/mojo/`. Vendored code under `build/` is excluded.

Status: review complete — all 482 functions read and checked off. Every source file was read in full.

## Findings (see `issues/*.md`)

| Issue | Severity | Where |
| --- | --- | --- |
| [multifab-copy-missing-validation](issues/multifab-copy-missing-validation.md) | High | `src/capi/multifab.cpp` `amrex_mojo_multifab_copy` / `MultiFab.copy_from` |
| [reduction-results-ignore-errors](issues/reduction-results-ignore-errors.md) | Medium | `MultiFab.min/max/sum/norm0/norm1/norm2` |
| [growntilebox-ngrow-unvalidated](issues/growntilebox-ngrow-unvalidated.md) | Medium | `MFIter._growntilebox_impl`, `src/capi/mfiter.cpp` |
| [heat-equation-valid-box-tiling](issues/heat-equation-valid-box-tiling.md) | Medium | `examples/HeatEquation/*.mojo` |
| [tileview-host-access-device-memory](issues/tileview-host-access-device-memory.md) | Medium-Low | `MultiFab._array_for_mfiter`, examples |
| [ffi-ignored-status-codes](issues/ffi-ignored-status-codes.md) | Medium-Low | `mojo/amrex/ffi.mojo` |
| [parallelfor-loads-default-library](issues/parallelfor-loads-default-library.md) | Medium-Low | `mojo/amrex/space3d/parallelfor.mojo` |
| [gpu-parallelfor-empty-box](issues/gpu-parallelfor-empty-box.md) | Low | `mojo/amrex/space3d/parallelfor.mojo` |
| [runtime-create-state-leak](issues/runtime-create-state-leak.md) | Low | `src/capi/init.cpp` |
| [f32-reductions-float-accumulation](issues/f32-reductions-float-accumulation.md) | Low | `src/capi/multifab.cpp` |
| [staged-array4-size-mismatch](issues/staged-array4-size-mismatch.md) | Low | `mojo/amrex/space3d/gpu.mojo` |

# Mojo package

## mojo/amrex/__init__.mojo

_(no functions)_

## mojo/amrex/build_config.mojo

_(no functions)_

## mojo/amrex/ffi.mojo

- [x] `init_device_passable_value` (L36)
- [x] `_to_device_type` (L51)
- [x] `get_type_name` (L59)
- [x] `_to_device_type` (L71)
- [x] `get_type_name` (L79)
- [x] `_to_device_type` (L101)
- [x] `get_type_name` (L109)
- [x] `_to_device_type` (L159)
- [x] `get_type_name` (L167)
- [x] `storage_size` (L170)
- [x] `offset` (L182)
- [x] `get` (L190)
- [x] `set` (L195)
- [x] `device_view` (L210)
- [x] `_to_device_type` (L216)
- [x] `get_type_name` (L224)
- [x] `layout_metadata` (L227)
- [x] `storage_size` (L230)
- [x] `offset` (L233)
- [x] `__getitem__` (L236)
- [x] `__getitem__` (L239)
- [x] `__setitem__` (L242)
- [x] `__setitem__` (L245)
- [x] `fill` (L248)
- [x] `device_view` (L265)
- [x] `_to_device_type` (L272)
- [x] `get_type_name` (L280)
- [x] `array` (L283)
- [x] `fill` (L286)
- [x] `intvect3d` (L290)
- [x] `zero_intvect3d` (L294)
- [x] `realbox3d` (L298)
- [x] `box3d` (L316)
- [x] `box_cell_count` (L331)
- [x] `for_each_box_cell` (L339)
- [x] `last_error_message` (L348)
- [x] `raise_on_error` (L358)
- [x] `abi_version` (L363)
- [x] `runtime_create` (L367)
- [x] `runtime_create` (L371)
- [x] `runtime_create` (L378)
- [x] `runtime_create` (L408)
- [x] `runtime_destroy` (L447)
- [x] `runtime_initialized` (L451)
- [x] `gpu_backend` (L455)
- [x] `gpu_device_id` (L459)
- [x] `gpu_num_streams` (L463)
- [x] `gpu_set_stream_index` (L467)
- [x] `gpu_reset_stream` (L471)
- [x] `gpu_stream` (L475)
- [x] `gpu_stream_synchronize_active` (L484)
- [x] `parallel_nprocs` (L488)
- [x] `parallel_myproc` (L492)
- [x] `parallel_ioprocessor` (L496)
- [x] `parallel_ioprocessor_number` (L500)
- [x] `boxarray_create_from_box` (L504)
- [x] `boxarray_destroy` (L513)
- [x] `boxarray_max_size` (L517)
- [x] `boxarray_size` (L522)
- [x] `distmap_create_from_boxarray` (L526)
- [x] `distmap_destroy` (L537)
- [x] `geometry_create` (L541)
- [x] `geometry_create` (L548)
- [x] `geometry_destroy` (L561)
- [x] `multifab_create` (L565)
- [x] `multifab_destroy` (L596)
- [x] `multifab_ncomp` (L600)
- [x] `multifab_datatype` (L604)
- [x] `multifab_memory_info` (L608)
- [x] `multifab_set_val` (L621)
- [x] `multifab_tile_count` (L633)
- [x] `multifab_tile_box` (L637)
- [x] `multifab_valid_box` (L642)
- [x] `mfiter_create` (L647)
- [x] `mfiter_destroy` (L656)
- [x] `mfiter_is_valid` (L660)
- [x] `mfiter_next` (L664)
- [x] `mfiter_index` (L668)
- [x] `mfiter_local_tile_index` (L672)
- [x] `box_from_bounds` (L676)
- [x] `box_from_parts` (L683)
- [x] `_mfiter_box_query` (L693)
- [x] `_mfiter_box_query_with_ngrow` (L711)
- [x] `mfiter_tile_box` (L732)
- [x] `mfiter_valid_box` (L736)
- [x] `mfiter_fab_box` (L740)
- [x] `mfiter_growntile_box` (L744)
- [x] `_mfiter_scalar_data_ptr` (L748)
- [x] `_array4_view_from_mfiter_impl` (L769)
- [x] `_array4_view_from_mfiter` (L808)
- [x] `_device_array4_view_from_mfiter` (L814)
- [x] `array4_view_from_mfiter` (L820)
- [x] `device_array4_view_from_mfiter` (L827)
- [x] `device_array4_view_from_mfiter_as_origin` (L833)
- [x] `multifab_sum` (L840)
- [x] `boxarray_box` (L844)
- [x] `geometry_domain` (L849)
- [x] `geometry_prob_domain` (L854)
- [x] `geometry_cell_size` (L859)
- [x] `geometry_periodicity` (L864)
- [x] `multifab_min` (L869)
- [x] `multifab_max` (L873)
- [x] `multifab_norm0` (L877)
- [x] `multifab_norm1` (L881)
- [x] `multifab_norm2` (L885)
- [x] `multifab_plus` (L889)
- [x] `multifab_mult` (L903)
- [x] `multifab_copy` (L917)
- [x] `multifab_parallel_copy` (L952)
- [x] `multifab_fill_boundary` (L997)
- [x] `multifab_write_single_level_plotfile` (L1016)
- [x] `multifab_write_single_level_plotfile` (L1036)
- [x] `parmparse_create` (L1055)
- [x] `parmparse_create` (L1062)
- [x] `parmparse_destroy` (L1070)
- [x] `parmparse_add_int` (L1074)
- [x] `parmparse_add_int` (L1090)
- [x] `parmparse_query_int` (L1105)
- [x] `parmparse_query_int` (L1126)
- [x] `parmparse_query_real` (L1146)
- [x] `parmparse_query_real` (L1167)

## mojo/amrex/floating_dtype.mojo

- [x] `mfiter_host_data_ptr` (L20)
- [x] `mfiter_device_data_ptr` (L30)
- [x] `mfiter_host_data_ptr` (L48)
- [x] `mfiter_device_data_ptr` (L61)
- [x] `mfiter_host_data_ptr` (L82)
- [x] `mfiter_device_data_ptr` (L95)

## mojo/amrex/loader.mojo

- [x] `resolve_library_candidate` (L6)
- [x] `installed_library_path` (L18)
- [x] `default_library_path` (L38)
- [x] `load_library` (L50)
- [x] `load_default_library` (L67)

## mojo/amrex/ownership.mojo

- [x] `require_live_handle` (L9)
- [x] `_optional_handle` (L29)
- [x] `_handle` (L32)
- [x] `destroy_amrex_optional_handle` (L36)

## mojo/amrex/runtime.mojo

- [x] `_require_runtime_handle` (L42)
- [x] `_make_runtime_state` (L48)
- [x] `require_matching_gpu_context` (L52)
- [x] `__init__` (L82)
- [x] `__init__` (L90)
- [x] `__init__` (L98)
- [x] `__init__` (L106)
- [x] `__init__` (L114)
- [x] `__init__` (L122)
- [x] `__init__` (L135)
- [x] `__init__` (L143)
- [x] `abi_version` (L157)
- [x] `initialized` (L161)
- [x] `nprocs` (L165)
- [x] `myproc` (L169)
- [x] `ioprocessor` (L173)
- [x] `ioprocessor_number` (L177)
- [x] `library_path` (L181)
- [x] `gpu_backend_code` (L185)
- [x] `gpu_backend` (L189)
- [x] `gpu_device_id` (L197)
- [x] `gpu_num_streams` (L201)
- [x] `gpu_set_stream_index` (L205)
- [x] `gpu_reset_stream` (L209)
- [x] `gpu_stream_handle` (L213)
- [x] `gpu_synchronize_active_streams` (L221)
- [x] `_lease` (L225)
- [x] `_handle` (L232)
- [x] `close` (L236)

## mojo/amrex/space3d/__init__.mojo

_(no functions)_

## mojo/amrex/space3d/box.mojo

_(no functions)_

## mojo/amrex/space3d/boxarray.mojo

- [x] `__init__` (L29)
- [x] `__del__` (L35)
- [x] `_optional_handle` (L38)
- [x] `max_size` (L41)
- [x] `max_size` (L45)
- [x] `size` (L48)
- [x] `box` (L52)
- [x] `__init__` (L67)
- [x] `__del__` (L73)
- [x] `_optional_handle` (L76)

## mojo/amrex/space3d/geometry.mojo

- [x] `__init__` (L27)
- [x] `__init__` (L33)
- [x] `__del__` (L51)
- [x] `_optional_handle` (L54)
- [x] `domain` (L57)
- [x] `prob_domain` (L61)
- [x] `cell_size` (L65)
- [x] `periodicity` (L69)

## mojo/amrex/space3d/gpu.mojo

- [x] `array4_storage_size` (L12)
- [x] `__init__` (L25)
- [x] `device_view` (L34)
- [x] `load_from_host` (L37)
- [x] `store_to_host` (L42)
- [x] `__init__` (L52)
- [x] `cell_count` (L58)
- [x] `device_view` (L61)
- [x] `store_to_host` (L64)

## mojo/amrex/space3d/mfiter.mojo

- [x] `__iter__` (L49)
- [x] `__next__` (L59)
- [x] `_box_from_raw_parts` (L63)
- [x] `__init__` (L90)
- [x] `__del__` (L119)
- [x] `_optional_handle` (L134)
- [x] `_is_valid` (L137)
- [x] `__next__` (L141)
- [x] `__iter__` (L209)
- [x] `index` (L212)
- [x] `local_tile_index` (L216)
- [x] `tilebox` (L220)
- [x] `validbox` (L227)
- [x] `fabbox` (L234)
- [x] `growntilebox` (L241)
- [x] `growntilebox` (L244)
- [x] `growntilebox` (L247)
- [x] `parallel_for` (L250)
- [x] `stream_index` (L264)
- [x] `stream_handle` (L269)
- [x] `stream` (L280)
- [x] `synchronize` (L284)
- [x] `_growntilebox_impl` (L288)
- [x] `_require_valid` (L306)
- [x] `_activate_current_stream` (L310)
- [x] `_refresh_stream_wrapper` (L313)
- [x] `_finalize` (L316)
- [x] `_finalize_no_error` (L327)
- [x] `_has_gpu_backend` (L343)
- [x] `_require_gpu_backend` (L346)
- [x] `create_mfiter` (L351)
- [x] `create_mfiter_range` (L363)
- [x] `create_gpu_mfiter` (L372)

## mojo/amrex/space3d/multifab.mojo

- [x] `apply` (L56)
- [x] `apply` (L69)
- [x] `apply` (L82)
- [x] `apply` (L95)
- [x] `_datatype_id` (L117)
- [x] `__init__` (L120)
- [x] `__del__` (L142)
- [x] `_optional_handle` (L145)
- [x] `ncomp` (L148)
- [x] `ngrow` (L152)
- [x] `memory_info` (L155)
- [x] `_use_device_array` (L159)
- [x] `_apply_scalar_op` (L162)
- [x] `set_val` (L178)
- [x] `set_val` (L181)
- [x] `tile_count` (L184)
- [x] `tile_box` (L188)
- [x] `valid_box` (L192)
- [x] `mfiter` (L196)
- [x] `gpu_mfiter` (L205)
- [x] `tiles` (L214)
- [x] `array` (L223)
- [x] `unsafe_device_array` (L228)
- [x] `tile` (L232)
- [x] `_array_for_mfiter` (L245)
- [x] `min` (L260)
- [x] `max` (L264)
- [x] `sum` (L268)
- [x] `norm0` (L272)
- [x] `norm1` (L276)
- [x] `norm2` (L280)
- [x] `plus` (L284)
- [x] `mult` (L293)
- [x] `copy_from` (L302)
- [x] `parallel_copy_from` (L324)
- [x] `fill_boundary` (L350)
- [x] `fill_boundary` (L370)
- [x] `write_single_level_plotfile` (L373)
- [x] `write_single_level_plotfile` (L393)
- [x] `_require_tile_index` (L407)

## mojo/amrex/space3d/parallelfor.mojo

- [x] `_parallel_for_cpu` (L33)
- [x] `ParallelForCpu` (L39)
- [x] `_gpu_context` (L45)
- [x] `ParallelFor` (L56)
- [x] `_parallel_for_kernel` (L85)
- [x] `ParallelFor` (L105)

## mojo/amrex/space3d/parmparse.mojo

- [x] `query_required` (L22)
- [x] `query_or` (L26)
- [x] `add` (L37)
- [x] `add` (L50)
- [x] `query_required` (L59)
- [x] `query_or` (L67)
- [x] `query_required` (L84)
- [x] `query_or` (L92)
- [x] `__init__` (L111)
- [x] `__init__` (L117)
- [x] `__del__` (L123)
- [x] `_optional_handle` (L126)
- [x] `add` (L129)
- [x] `add` (L133)
- [x] `query` (L136)
- [x] `query` (L140)
- [x] `get` (L143)
- [x] `get` (L146)
- [x] `query_or` (L149)
- [x] `query_or` (L153)

## mojo/amrex/space3d/tile_loop.mojo

_(no functions)_

## mojo/amrex/space3d/types.mojo

_(no functions)_

# C API shim

## src/capi/capi_internal.H

- [x] `clear_last_error` (L46, declaration)
- [x] `set_last_error` (L48, L51, declarations)
- [x] `retain_runtime` (L54, declaration)
- [x] `release_runtime` (L55, declaration)
- [x] `to_intvect` (L57)
- [x] `from_intvect` (L62)
- [x] `to_box` (L71)
- [x] `from_box` (L76)
- [x] `unit_realbox` (L85)
- [x] `to_realbox` (L90)
- [x] `from_realbox` (L98)
- [x] `from_cell_size` (L110)
- [x] `to_periodicity` (L119)
- [x] `to_scalar_ngrow` (L125)

## src/capi/error.cpp

- [x] `amrex_mojo_abi_version` (L10)
- [x] `amrex_mojo_last_error_message` (L15)
- [x] `clear_last_error` (L22)
- [x] `set_last_error` (L27, const char* overload)
- [x] `set_last_error` (L34, std::string overload)

## src/capi/init.cpp

- [x] `build_argv_storage` (L27)
- [x] `build_argv_ptrs` (L54)
- [x] `initialize_default_parmparse` (L65)
- [x] `parse_positive_env_int` (L75)
- [x] `detect_mpi_world_size_from_environment` (L94)
- [x] `non_mpi_launch_error` (L113)
- [x] `active_amrex_gpu_device_id` (L131)
- [x] `validate_requested_gpu_device` (L141)
- [x] `initialize_amrex_runtime` (L202)
- [x] `runtime_create_impl` (L233)
- [x] `retain_runtime` (L343)
- [x] `release_runtime` (L351)
- [x] `amrex_mojo_runtime_create` (L389)
- [x] `amrex_mojo_runtime_create_default` (L394)
- [x] `amrex_mojo_runtime_create_on_device` (L400)
- [x] `amrex_mojo_runtime_create_default_on_device` (L411)
- [x] `amrex_mojo_runtime_destroy` (L416)
- [x] `amrex_mojo_runtime_initialized` (L429)
- [x] `amrex_mojo_parallel_nprocs` (L435)
- [x] `amrex_mojo_parallel_myproc` (L441)
- [x] `amrex_mojo_parallel_ioprocessor` (L447)
- [x] `amrex_mojo_parallel_ioprocessor_number` (L453)

## src/capi/gpu.cpp

- [x] `amrex_mojo_gpu_backend` (L5)
- [x] `amrex_mojo_gpu_device_id` (L19)
- [x] `amrex_mojo_gpu_num_streams` (L35)
- [x] `amrex_mojo_gpu_set_stream_index` (L47)
- [x] `amrex_mojo_gpu_reset_stream` (L69)
- [x] `amrex_mojo_gpu_stream` (L80)
- [x] `amrex_mojo_gpu_stream_synchronize_active` (L102)

## src/capi/boxarray.cpp

- [x] `amrex_mojo_boxarray_create_from_box` (L4)
- [x] `amrex_mojo_boxarray_create_from_bounds` (L37)
- [x] `amrex_mojo_boxarray_destroy` (L60)
- [x] `amrex_mojo_boxarray_max_size` (L74)
- [x] `amrex_mojo_boxarray_max_size_xyz` (L98)
- [x] `amrex_mojo_boxarray_size` (L103)
- [x] `amrex_mojo_boxarray_box` (L117)
- [x] `amrex_mojo_boxarray_box_metadata` (L139)

## src/capi/distmap.cpp

- [x] `amrex_mojo_distmap_create_from_boxarray` (L4)
- [x] `amrex_mojo_distmap_destroy` (L36)

## src/capi/geometry.cpp

- [x] `amrex_mojo_geometry_create` (L4)
- [x] `amrex_mojo_geometry_create_with_real_box_and_periodicity` (L14)
- [x] `amrex_mojo_geometry_create_from_bounds` (L57)
- [x] `amrex_mojo_geometry_create_from_bounds_with_real_box_and_periodicity` (L81)
- [x] `amrex_mojo_geometry_destroy` (L122)
- [x] `amrex_mojo_geometry_domain` (L135)
- [x] `amrex_mojo_geometry_prob_domain` (L149)
- [x] `amrex_mojo_geometry_cell_size` (L163)
- [x] `amrex_mojo_geometry_periodicity` (L177)
- [x] `amrex_mojo_geometry_domain_metadata` (L195)
- [x] `amrex_mojo_geometry_prob_domain_metadata` (L226)
- [x] `amrex_mojo_geometry_cell_size_data` (L251)
- [x] `amrex_mojo_geometry_periodicity_data` (L268)

## src/capi/mfiter.cpp

- [x] `fill_box_arrays` (L5)
- [x] `require_current_tile` (L23)
- [x] `grown_tile_box` (L46)
- [x] `amrex_mojo_mfiter_create` (L66)
- [x] `amrex_mojo_mfiter_destroy` (L124)
- [x] `amrex_mojo_mfiter_is_valid` (L137)
- [x] `amrex_mojo_mfiter_next` (L151)
- [x] `amrex_mojo_mfiter_index` (L173)
- [x] `amrex_mojo_mfiter_local_tile_index` (L184)
- [x] `amrex_mojo_mfiter_tile_box_metadata` (L196)
- [x] `amrex_mojo_mfiter_valid_box_metadata` (L221)
- [x] `amrex_mojo_mfiter_fab_box_metadata` (L246)
- [x] `amrex_mojo_mfiter_growntile_box_metadata` (L271)

## src/capi/multifab.cpp

- [x] `multifab_has_value` (L10)
- [x] `require_live_multifab` (L19)
- [x] `visit_multifab` (L36, const overload)
- [x] `visit_multifab` (L45, mutable overload)
- [x] `visit_multifab_pair` (L54)
- [x] `require_tile` (L69)
- [x] `require_current_mfiter_tile` (L87)
- [x] `require_multifab_tile_for_mfiter` (L110)
- [x] `validate_component_range` (L147)
- [x] `arena_for_memory_kind` (L160)
- [x] `is_valid_memory_kind` (L168)
- [x] `mfinfo_for_memory_kind` (L176)
- [x] `is_valid_datatype` (L185)
- [x] `populate_tiles` (L195)
- [x] `require_host_accessible_typed` (L212)
- [x] `require_host_accessible` (L237)
- [x] `require_device_accessible_typed` (L257)
- [x] `require_device_accessible` (L282)
- [x] `fill_array4_metadata_from_fab` (L302)
- [x] `fill_array4_metadata_from_tile` (L324)
- [x] `data_ptr_from_tile_typed` (L371)
- [x] `require_valid_component` (L376)
- [x] `reduce_min_f32` (L398)
- [x] `reduce_max_f32` (L425)
- [x] `reduce_sum_f32` (L452)
- [x] `reduce_norm0_f32` (L479)
- [x] `reduce_norm1_f32` (L506)
- [x] `reduce_norm2_f32` (L533)
- [x] `amrex_mojo_multifab_create` (L563)
- [x] `amrex_mojo_multifab_create_with_memory` (L582)
- [x] `amrex_mojo_multifab_create_with_memory_and_datatype` (L603)
- [x] `amrex_mojo_multifab_create_xyz` (L709)
- [x] `amrex_mojo_multifab_create_with_memory_xyz` (L732)
- [x] `amrex_mojo_multifab_create_with_memory_and_datatype_xyz` (L757)
- [x] `amrex_mojo_multifab_destroy` (L780)
- [x] `amrex_mojo_multifab_ncomp` (L793)
- [x] `amrex_mojo_multifab_ngrow` (L803)
- [x] `amrex_mojo_multifab_datatype` (L817)
- [x] `amrex_mojo_multifab_memory_info` (L827)
- [x] `amrex_mojo_multifab_set_val` (L851)
- [x] `amrex_mojo_multifab_tile_count` (L900)
- [x] `amrex_mojo_multifab_tile_box` (L910)
- [x] `amrex_mojo_multifab_valid_box` (L921)
- [x] `amrex_mojo_multifab_array4_metadata_for_mfiter` (L933)
- [x] `amrex_mojo_multifab_data_ptr_for_mfiter` (L958)
- [x] `amrex_mojo_multifab_data_ptr_for_mfiter_device` (L985)
- [x] `amrex_mojo_multifab_data_ptr_for_mfiter_f32` (L1015)
- [x] `amrex_mojo_multifab_data_ptr_for_mfiter_device_f32` (L1045)
- [x] `amrex_mojo_multifab_min` (L1074)
- [x] `amrex_mojo_multifab_max` (L1087)
- [x] `amrex_mojo_multifab_sum` (L1100)
- [x] `amrex_mojo_multifab_norm0` (L1113)
- [x] `amrex_mojo_multifab_norm1` (L1126)
- [x] `amrex_mojo_multifab_norm2` (L1139)
- [x] `amrex_mojo_multifab_plus` (L1153)
- [x] `amrex_mojo_multifab_mult` (L1207)
- [x] `amrex_mojo_multifab_copy` (L1261)
- [x] `amrex_mojo_multifab_copy_xyz` (L1324)
- [x] `amrex_mojo_multifab_parallel_copy` (L1346)
- [x] `amrex_mojo_multifab_parallel_copy_xyz` (L1426)
- [x] `amrex_mojo_multifab_fill_boundary` (L1454)
- [x] `amrex_mojo_write_single_level_plotfile` (L1504)

## src/capi/parmparse.cpp

- [x] `amrex_mojo_parmparse_create` (L4)
- [x] `amrex_mojo_parmparse_destroy` (L36)
- [x] `amrex_mojo_parmparse_add_int` (L50)
- [x] `amrex_mojo_parmparse_query_int` (L74)
- [x] `amrex_mojo_parmparse_query_real` (L105)

# Examples and tests

## examples/Multifab/multifab.mojo

- [x] `fill_tile` (L17)
- [x] `main` (L21)
- [x] `update_tile` (L62)

## examples/Multifab/multifab_mpi.mojo

- [x] `expect` (L23)
- [x] `expect_close` (L28)
- [x] `fill_box_value` (L40)
- [x] `slab_fill_value` (L49)
- [x] `slab_neighbor_value` (L55)
- [x] `box_contains` (L61)
- [x] `has_nonzero_ghost_cells` (L72)
- [x] `interface_ghost_sample` (L92)
- [x] `interface_expected_value` (L109)
- [x] `main` (L119)

## examples/HeatEquation/heat_equation.mojo

- [x] `plotfile_name` (L26)
- [x] `main` (L38)
- [x] `initialize_cell` (L101)
- [x] `advance_cell` (L136)

## examples/HeatEquation/heat_equation_vis.mojo

- [x] `initialize_phi` (L26)
- [x] `initialize_cell` (L33)
- [x] `__init__` (L55)
- [x] `__del__` (L114)
- [x] `slice_array` (L117)
- [x] `step` (L130)
- [x] `advance_cell` (L144)
- [x] `py_init` (L163)
- [x] `step_py` (L173)
- [x] `slice_array_py` (L178)
- [x] `current_step_py` (L185)
- [x] `nsteps_py` (L190)
- [x] `write_to` (L194)
- [x] `write_repr_to` (L203)
- [x] `PyInit_heat_equation_vis` (L208)

## tests/mojo/runtime_geometry_test.mojo

- [x] `expect` (L20)
- [x] `main` (L25)

## tests/mojo/multifab_functional_test.mojo

- [x] `expect` (L21)
- [x] `expect_equal` (L26)
- [x] `main` (L30)
- [x] `add_cell` (L88)
- [x] `add_cell_f32` (L200)
- [x] `fill_rank_cell` (L234)

