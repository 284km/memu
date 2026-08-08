#!/bin/sh
# Run the interactive fantasy console headlessly: compile the RV32IM cartridge
# (game.mere) with `mere -rv`, then run it on rv32i_play.mere, which drives a
# few frames with scripted arrow-key input and dumps the framebuffer each time
# so the player block is seen to move. The live browser version (same emulator
# compiled to Wasm) is at merelang.org/playground/rvconsole.html.
#
#   MERE=/path/to/mere sh play.sh
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"
"$MERE" -c "$DIR/rv32i_play.mere" > "$DIR/playrun.c"
clang -O2 -w "$DIR/playrun.c" -o "$DIR/playrun"
"$MERE" -rv "$DIR/game.mere" > "$DIR/game.bin"
( cd "$DIR" && ./playrun )
rm -f "$DIR/playrun" "$DIR/playrun.c" "$DIR/game.bin"
