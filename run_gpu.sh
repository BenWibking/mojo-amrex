#!/bin/bash

set -x
ulimit -c 0
unset HSA_ENABLE_DEBUG

mojo -I mojo examples/multifab_gpu_interop.mojo
