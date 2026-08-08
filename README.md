# memu — CPU emulators written in Mere

A small ladder of CPU emulators implemented in the
[Mere](https://github.com/merelang/mere) programming language. Each emulator
is a self-contained fetch–decode–execute core that runs **identically on all
four Mere backends** — the tree-walking interpreter, the C backend, the LLVM
backend, and the WebAssembly backend.

The point of the ladder is pedagogical: every rung adds exactly one layer of
the "what makes a CPU hard to emulate" problem on top of the one before it.

| Emulator | File | What it adds over the previous rung |
|----------|------|-------------------------------------|
| **CHIP-8** | [`chip8.mere`](chip8.mere) | The basics: a byte-addressed memory, a register file, opcode decode with the bitwise builtins, a framebuffer, timers, and a seeded RNG. |
| **MOS 6502** | [`mos6502.mere`](mos6502.mere) | A real 8-bit CPU: the rich 6502 addressing modes (immediate, zero-page[,X/Y], absolute[,X/Y], (indirect,X), (indirect),Y, relative), a status register whose flags are updated after every operation, and a hardware stack in page 1 (JSR/RTS). The **complete** core (all opcodes + decimal mode) passes Klaus Dörmann's functional test — see [`klaus/`](klaus/). |
| **Game Boy (Sharp LR35902)** | [`gameboy.mere`](gameboy.mere) | 16-bit register *pairs* (BC/DE/HL/SP) and the **half-carry** flag — carry out of bit 3 on 8-bit ops and out of bit 11 on `ADD HL,rr`. Its regular opcode map is decoded from bit-fields, and the `CB` prefix opens a second opcode table (rotates / SWAP / BIT / RES / SET). The **complete** core passes 10/11 of Blargg's `cpu_instrs` tests (all but the interrupt test) — see [`blargg/`](blargg/). |
| **RISC-V RV32I** | [`riscv.mere`](riscv.mere) | A modern 32-bit ISA: 32 registers (x0 hardwired to 0), fixed-width 32-bit instructions in six formats (R/I/S/B/U/J) whose immediates are scattered across the word and must be reassembled and sign-extended. The test program is built by a tiny in-program assembler whose encoders mirror the emulator's decoders. The core is fuzzed against an independent reference (~240k random instructions) — see [`riscv-difftest/`](riscv-difftest/). |

Everything is 8-/16-/32-bit integer work over a flat `Vec[int]` memory, so the
programs are fully deterministic and byte-identical across the four backends.

## Running

You need the [Mere](https://github.com/merelang/mere) compiler on your `PATH`
(as `mere`). Each emulator loads a small hand-assembled program, runs it to a
halt, and prints the final machine state.

```sh
# On the interpreter:
mere -I . chip8.mere
mere -I . mos6502.mere
mere -I . gameboy.mere
mere -I . riscv.mere
```

The `-I .` tells Mere where to find [`common.mere`](common.mere), a small
module of shared primitives (fixed-width masks, a zero-filled vector builder,
and a routine to copy a `bytes` ROM into memory) that every emulator imports.

To compile an emulator through one of the other backends instead of
interpreting it:

```sh
mere -c  -I . mos6502.mere   # emit C     (then compile with clang)
mere -ll -I . mos6502.mere   # emit LLVM  (then compile with clang)
mere -w  -I . mos6502.mere   # emit WebAssembly (WAT)
```

`verify.sh` runs each emulator on the interpreter, the C backend, and the LLVM
backend and checks the three outputs agree:

```sh
MERE=/path/to/mere sh verify.sh
```

## Scope

These are **CPU cores**, not full machines. There is no graphics/PPU, no sound,
no timers or interrupts beyond what each test needs, and no peripheral I/O. The
6502 has no decimal (BCD) mode; the Game Boy core has no DAA/STOP; the RISC-V
core is base RV32I only (no CSRs, traps, or M/A/F extensions). Each emulator
runs a fixed hand-assembled program and verifies the resulting registers,
memory, and flags — enough to exercise the interesting parts of each ISA
without a full ROM/BIOS.

## License

MIT — see [LICENSE](LICENSE).
