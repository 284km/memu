#!/bin/sh
# Milestone 1: run Blargg's cpu_instrs suite (all 11, incl. 02-interrupts) on
# the full Game Boy machine. Needs the Mere compiler + clang + curl.
#   MERE=/path/to/mere sh run.sh
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="https://raw.githubusercontent.com/retrio/gb-test-roms/master/cpu_instrs/individual"
TESTS='01-special
02-interrupts
03-op sp,hl
04-op r,imm
05-op rp
06-ld r,r
07-jr,jp,call,ret,rst
08-misc instrs
09-op r,r
10-bit ops
11-op a,(hl)'

"$MERE" -c "$DIR/gb_machine.mere" > "$DIR/gb.c"
clang -O2 -w "$DIR/gb.c" -o "$DIR/gb"
mkdir -p "$DIR/roms"
OLDIFS=$IFS; IFS='
'
for name in $TESTS; do
  rom="$DIR/roms/$name.gb"
  [ -f "$rom" ] || curl -sSL -o "$rom" "$BASE/$(printf '%s' "$name" | sed 's/ /%20/g; s/,/%2C/g').gb"
  cp "$rom" "$DIR/rom.gb"
  res=$( cd "$DIR" && ./gb 2>&1 | grep -iE 'passed|failed' | head -1 | tr -d '\r' )
  printf '%-24s -> %s\n' "$name" "${res:-<none>}"
done
IFS=$OLDIFS
rm -f "$DIR/rom.gb" "$DIR/gb" "$DIR/gb.c"
