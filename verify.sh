#!/bin/sh
# Run every emulator on the interpreter, the C backend, and the LLVM backend
# and check the three outputs agree. Set MERE to the Mere compiler if it is
# not on your PATH as `mere`. Requires clang for the C/LLVM backends.
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
for f in chip8 mos6502 gameboy riscv; do
  src="$DIR/$f.mere"
  i="$("$MERE" -I "$DIR" "$src")"
  "$MERE" -c  -I "$DIR" "$src" > "$TMP/$f.c"  && clang -w "$TMP/$f.c"  -o "$TMP/$f.cbin" && c="$("$TMP/$f.cbin")"
  "$MERE" -ll -I "$DIR" "$src" > "$TMP/$f.ll" && clang -w "$TMP/$f.ll" -o "$TMP/$f.lbin" && l="$("$TMP/$f.lbin")"
  if [ "$i" = "$c" ] && [ "$i" = "$l" ]; then
    echo "ok   $f  (interp = c = llvm)"
  else
    echo "FAIL $f"; echo "  interp: $i"; echo "  c:      $c"; echo "  llvm:   $l"; fail=1
  fi
done
exit $fail
