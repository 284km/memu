#!/bin/sh
# Compile a freestanding C program to RISC-V RV32I with gcc, then run it on the
# Mere RV32I emulator. Requires a bare-metal RISC-V toolchain and the Mere
# compiler + clang.
#   brew install riscv64-elf-gcc      # provides riscv64-elf-{gcc,objcopy}
#   MERE=/path/to/mere sh run.sh
set -e
MERE="${MERE:-mere}"
GCC="${RISCV_GCC:-riscv64-elf-gcc}"
OBJCOPY="${RISCV_OBJCOPY:-riscv64-elf-objcopy}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# C -> RV32I ELF -> flat binary. -lgcc supplies the soft mul/div RV32I has no
# instructions for; the linker script puts _start at address 0.
"$GCC" -march=rv32i -mabi=ilp32 -nostdlib -O2 -ffreestanding \
  -T "$DIR/link.ld" "$DIR/hello.c" -lgcc -o "$DIR/hello.elf"
"$OBJCOPY" -O binary "$DIR/hello.elf" "$DIR/prog.bin"

# build the Mere emulator (C backend) and run it where prog.bin lives
"$MERE" -c "$DIR/rv32i_run.mere" > "$DIR/rvrun.c"
clang -O2 -w "$DIR/rvrun.c" -o "$DIR/rvrun"
( cd "$DIR" && ./rvrun )

rm -f "$DIR/hello.elf" "$DIR/prog.bin" "$DIR/rvrun" "$DIR/rvrun.c"
