# ABOUTME: Top-level package entry point for the AMReX Mojo bindings.
# ABOUTME: Re-exports the public C API loader and 3D binding modules.

"""Top-level package for the AMReX Mojo MVP bindings."""

from amrex.loader import (
    default_library_path,
    installed_library_path,
    load_default_library,
    load_library,
)
from amrex.space3d import *
