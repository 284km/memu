#!/bin/sh
# Compile the RV32I core and run the differential test against the independent
# Python reference. Set MERE to the Mere compiler if not on PATH as `mere`.
# Requires clang, python3.
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"
"$MERE" -c "$DIR/rv32i_core.mere" > "$DIR/rvdump.c"
clang -O2 -w "$DIR/rvdump.c" -o "$DIR/rvdump"
python3 "$DIR/difftest.py" "$DIR/rvdump" "$DIR" "${1:-1000}" "${2:-60}"
rm -f "$DIR/rvdump" "$DIR/rvdump.c" "$DIR/prog.bin"
