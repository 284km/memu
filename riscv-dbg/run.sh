#!/bin/sh
# Build the debugger and drive it through a scripted session.
#
#   MERE=/path/to/mere sh run.sh          # the canned demo below
#   MERE=... sh run.sh -i                 # interactive, on the same program
#
# `mere -rv` emits the binary and `mere -rvg` the debug map beside it — both from
# the same item list, so the map describes the bytes that run. The debugger loads
# prog.bin, prog.map and prog.mere from its own directory.
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"

"$MERE" -c "$DIR/rv32i_dbg.mere" > "$DIR/rvdbg.c"
clang -O2 -w "$DIR/rvdbg.c" -o "$DIR/rvdbg"

cp "$DIR/demo.mere" "$DIR/prog.mere"
"$MERE" -rv  "$DIR/prog.mere" > "$DIR/prog.bin"
"$MERE" -rvg "$DIR/prog.mere" > "$DIR/prog.map"

cd "$DIR"
if [ "$1" = "-i" ]; then
  ./rvdbg
else
  # break inside the recursion, look around, then walk backwards out of it
  printf 'b 6\nr\nw\nbt\np\ns\ns\nbt\nn\nS\nS\nS\nn\nw\nc\nq\n' | ./rvdbg
fi
rm -f "$DIR/rvdbg" "$DIR/rvdbg.c" "$DIR/prog.mere" "$DIR/prog.bin" "$DIR/prog.map"
