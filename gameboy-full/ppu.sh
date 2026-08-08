#!/bin/sh
# Milestone 2: render mattcurrie's dmg-acid2 PPU test ROM and dump the frame as
# downsampled ASCII. Needs the Mere compiler + clang + curl.
#   MERE=/path/to/mere sh ppu.sh
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"
rom="$DIR/dmg-acid2.gb"
[ -f "$rom" ] || curl -sSL -o "$rom" \
  "https://github.com/mattcurrie/dmg-acid2/releases/download/v1.0/dmg-acid2.gb"
"$MERE" -c "$DIR/gb_ppu.mere" > "$DIR/gbppu.c"
clang -O2 -w "$DIR/gbppu.c" -o "$DIR/gbppu"
cp "$rom" "$DIR/rom.gb"
( cd "$DIR" && ./gbppu )
rm -f "$DIR/rom.gb" "$DIR/gbppu" "$DIR/gbppu.c"
