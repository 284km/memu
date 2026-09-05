#!/bin/sh
# rvv_check.sh -- compile both RISC-V cores and run the RVV subset's directed tests
# (riscv-runc/rvv_check.py): the Python model, memu (rv32 and rv64) and, when
# qemu-system-riscv32 is on PATH, QEMU with `-cpu rv32,v=true,vlen=128` must all
# produce the same bytes. Set MERE to the Mere compiler if it is not `mere` on PATH.
set -e
MERE="${MERE:-mere}"
DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
for c in rv32i_run rv64i_run; do
  "$MERE" -c "$DIR/$c.mere" > "$TMP/$c.c"
  clang -O2 -w "$TMP/$c.c" -o "$TMP/$c"
done
python3 "$DIR/rvv_check.py" "$TMP/rv32i_run" "$TMP/rv64i_run"
