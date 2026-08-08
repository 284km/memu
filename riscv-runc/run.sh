#!/bin/sh
# Compile freestanding C programs to RISC-V RV32IM with gcc, then run them on
# the Mere RV32IM emulator. Requires a bare-metal RISC-V toolchain + Mere + clang.
#   brew install riscv64-elf-gcc      # provides riscv64-elf-{gcc,objcopy}
#   MERE=/path/to/mere sh run.sh
set -e
MERE="${MERE:-mere}"
GCC="${RISCV_GCC:-riscv64-elf-gcc}"
OBJCOPY="${RISCV_OBJCOPY:-riscv64-elf-objcopy}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# build the Mere emulator once (C backend)
"$MERE" -c "$DIR/rv32i_run.mere" > "$DIR/rvrun.c"
clang -O2 -w "$DIR/rvrun.c" -o "$DIR/rvrun"

for src in hello app; do
  # C -> RV32IM ELF -> flat binary. -lgcc supplies any runtime helpers;
  # the linker script puts _start at address 0.
  "$GCC" -march=rv32im -mabi=ilp32 -nostdlib -O2 -ffreestanding \
    -T "$DIR/link.ld" "$DIR/$src.c" -lgcc -o "$DIR/$src.elf"
  "$OBJCOPY" -O binary "$DIR/$src.elf" "$DIR/prog.bin"
  echo "=== $src.c ==="
  ( cd "$DIR" && ./rvrun )
  echo
done
rm -f "$DIR"/*.elf "$DIR/prog.bin" "$DIR/rvrun" "$DIR/rvrun.c"
