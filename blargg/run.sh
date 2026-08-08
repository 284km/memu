#!/bin/sh
# Fetch Blargg's cpu_instrs individual ROMs and run each through the LR35902
# core. Set MERE to the Mere compiler if it is not on PATH as `mere`.
# Requires clang, curl.
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="https://raw.githubusercontent.com/retrio/gb-test-roms/master/cpu_instrs/individual"
# newline-separated (test names contain spaces and commas)
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

# compile the core once
"$MERE" -c "$DIR/gb_cpu_instrs.mere" > "$DIR/gb.c"
clang -O2 -w "$DIR/gb.c" -o "$DIR/gb"

OLDIFS=$IFS; IFS='
'
for name in $TESTS; do
  rom="$DIR/roms/$name.gb"
  mkdir -p "$DIR/roms"
  if [ ! -f "$rom" ]; then
    enc=$(printf '%s' "$name" | sed 's/ /%20/g; s/,/%2C/g')
    curl -sSL -o "$rom" "$BASE/$enc.gb"
  fi
  cp "$rom" "$DIR/rom.gb"
  ( cd "$DIR" && result=$(./gb 2>&1 | grep -iE 'passed|failed' | head -1 | tr -d '\r')
    printf '%-26s -> %s\n' "$name" "${result:-<no result>}" )
done
IFS=$OLDIFS
rm -f "$DIR/rom.gb" "$DIR/gb.c" "$DIR/gb"
