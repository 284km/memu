# Klaus 6502 functional test

[`klaus_test.mere`](klaus_test.mere) is the complete MOS 6502 core (every
official opcode and addressing mode, read-modify-write, the packed status
register, BRK/RTI, the JMP-indirect page-wrap bug, and decimal/BCD mode with
NMOS flag behaviour) run against **Klaus Dörmann's `6502_functional_test`** —
the de-facto gold standard for 6502 correctness. It exercises essentially the
entire instruction set and traps in an infinite loop at the address of the
first failing test, or at `$3469` (`JMP *`) once every test has passed.

The Mere core reaches **`$3469`** — a full pass — on the interpreter, C, and
LLVM backends.

## Running

The test ROM is GPL-licensed and is **not** redistributed here. Fetch it into
this directory first:

```sh
curl -L -o 6502_functional_test.bin \
  https://raw.githubusercontent.com/Klaus2m5/6502_65C02_functional_tests/master/bin_files/6502_functional_test.bin
```

Then run the harness (it reads the ROM from the current directory):

```sh
# Fast — compile through the C backend:
mere -c klaus_test.mere > k.c && clang -O2 k.c -o k && ./k

# Or on the interpreter (correct but slow — the full test is tens of
# millions of instructions on a tree-walker):
mere klaus_test.mere
```

A pass prints:

```
trap_pc=13417        # $3469 — every test passed
marker_0200=240
```

Any other `trap_pc` is the address of the failing test; `trap_pc=-2` means an
unknown opcode was hit (a gap in the core).

## Relationship to `../mos6502.mere`

The [`mos6502.mere`](../mos6502.mere) in the repo root is the compact
teaching rung of the ladder — a readable subset with a small hand-assembled
program. This directory holds the *complete*, conformance-verified core; the
two share the same design, and this one fills in every remaining opcode plus
decimal mode.
