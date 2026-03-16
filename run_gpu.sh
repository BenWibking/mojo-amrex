#!/bin/bash

set -x
ulimit -c 0
unset HSA_ENABLE_DEBUG

pixi run mojo -I mojo examples/Multifab/multifab_gpu.mojo

