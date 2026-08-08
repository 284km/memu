#!/bin/sh
# Measure the throughput (MIPS) of the Mere RV32IM emulator across backends by
# running a fixed compute benchmark (bench.c) and dividing the executed
# instruction count by the wall-clock time.
#   brew install riscv64-elf-gcc ; MERE=/path/to/mere sh run.sh
set -e
MERE="${MERE:-mere}"
GCC="${RISCV_GCC:-riscv64-elf-gcc}"
OBJCOPY="${RISCV_OBJCOPY:-riscv64-elf-objcopy}"
DIR="$(cd "$(dirname "$0")" && pwd)"

"$GCC" -march=rv32im -mabi=ilp32 -nostdlib -O2 -ffreestanding \
  -T "$DIR/../riscv-runc/link.ld" "$DIR/bench.c" -lgcc -o "$DIR/bench.elf"
"$OBJCOPY" -O binary "$DIR/bench.elf" "$DIR/prog.bin"

measure() {   # $1 = label, $2 = emulator binary
  n=$(cd "$DIR" && ./"$2" | grep instructions= | cut -d= -f2)
  t=$( { /usr/bin/time -p "$DIR/$2" >/dev/null; } 2>&1 | awk '/real/{print $2}' )
  awk -v n="$n" -v t="$t" -v l="$1" 'BEGIN{printf "%-6s %s instrs in %ss  =>  %.0f MIPS\n", l, n, t, (n/t)/1e6}'
}

"$MERE" -c  "$DIR/rv32i_bench.mere" > "$DIR/b.c"  && clang -O2 -w "$DIR/b.c"  -o "$DIR/bench_c"  && ( cd "$DIR" && measure C  bench_c )
"$MERE" -ll "$DIR/rv32i_bench.mere" > "$DIR/b.ll" && clang -O2 -w "$DIR/b.ll" -o "$DIR/bench_ll" && ( cd "$DIR" && measure LLVM bench_ll )
echo "(the tree-walk interpreter runs the same core but is ~10000x slower on this tight loop)"
rm -f "$DIR"/bench.elf "$DIR"/prog.bin "$DIR"/b.c "$DIR"/b.ll "$DIR"/bench_c "$DIR"/bench_ll
