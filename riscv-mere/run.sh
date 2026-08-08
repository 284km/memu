#!/bin/sh
# Compile Mere programs directly to RV32IM with `mere -rv` and run them on the
# Mere-written RISC-V emulator (../riscv-runc/rv32i_run.mere).
#
#   MERE=/path/to/mere sh run.sh
#
# `mere -rv file.mere > prog.bin` emits a flat little-endian RV32IM binary with
# no external assembler or linker; the emulator loads it at address 0 and runs
# from _start. The same backend compiles Mere's own self-hosted compiler (from
# github.com/merelang/mere, contrib/), so the Mere compiler can compile Mere
# programs while running on this emulator — self-language on self-CPU.
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# Build the emulator once (via the C backend). It has an 8 MB address space,
# which the `mere -rv` memory map (globals+heap at 2 MB, stack near 8 MB) needs.
"$MERE" -c "$DIR/../riscv-runc/rv32i_run.mere" > "$DIR/rvrun.c"
clang -O2 -w "$DIR/rvrun.c" -o "$DIR/rvrun"

for src in demo; do
  echo "=== $src.mere ==="
  "$MERE" -rv "$DIR/$src.mere" > "$DIR/prog.bin"
  ( cd "$DIR" && ./rvrun )
  echo
done
rm -f "$DIR/rvrun" "$DIR/rvrun.c" "$DIR/prog.bin"
