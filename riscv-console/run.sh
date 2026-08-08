#!/bin/sh
# A tiny "fantasy console": a Mere program draws to a framebuffer and this
# RISC-V emulator renders it as ASCII. `mere -rv` lowers `fb_set x y v` to a
# store into a 64x32 framebuffer at 0x7F8000; rv32i_console.mere reads that
# region after the program halts and prints it as a shade ramp.
#
#   MERE=/path/to/mere sh run.sh
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"
"$MERE" -c "$DIR/rv32i_console.mere" > "$DIR/conrun.c"
clang -O2 -w "$DIR/conrun.c" -o "$DIR/conrun"
"$MERE" -rv "$DIR/console.mere" > "$DIR/prog.bin"
( cd "$DIR" && ./conrun )
echo
rm -f "$DIR/conrun" "$DIR/conrun.c" "$DIR/prog.bin"
