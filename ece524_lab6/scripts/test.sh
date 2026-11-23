#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/lab6-verilator.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export CCACHE_DISABLE=1
# Xilinx FPGA register initialization is intentional (configuration INIT values).
verilator --lint-only -Wall -Wno-PROCASSINIT --top-module main_fsm ece524_lab6.srcs/sources_1/new/*.v
verilator --binary -j 4 --timing -Wno-PROCASSINIT --top-module tb_lab6 \
  --Mdir "$build_dir" ece524_lab6.srcs/sources_1/new/*.v tests/tb_lab6.sv > "$build_dir/build.log" 2>&1 || { cat "$build_dir/build.log"; exit 1; }
"$build_dir/Vtb_lab6"
