# Running real compiled software on the RV32IM core

This runs actual C programs — compiled by `gcc` to RISC-V — on the CPU emulator
written in Mere. [`rv32i_run.mere`](rv32i_run.mere) is the RV32I core (see
[`../riscv.mere`](../riscv.mere)) extended with the **M extension**
(multiply/divide), a flat-binary loader, and a minimal syscall ABI on `ecall`:

| `a7` | syscall | effect |
|------|---------|--------|
| 64 | `write(fd, buf, len)` | copy `len` bytes from `buf` to stdout |
| 93 | `exit(code)` | halt |

Both programs are freestanding (their own `_start`, no libc), compiled to a
flat binary and executed by the emulator — with identical output on the
interpreter, C, and LLVM backends.

### [`hello.c`](hello.c) — the smoke test

```
Hello from C, compiled to RISC-V RV32I, running on a Mere emulator!
sum 1..100 = 5050
fib(20)    = 6765
```

### [`app.c`](app.c) — a bigger program

A prime sieve over dynamically-allocated memory (a small bump allocator), a
recursive quicksort, and a factorial — exercising the M extension (`mul`,
`div`, `rem`, and the `mulhu` that gcc emits for divide-by-constant):

```
A bigger C program on the Mere RV32I(M) emulator
-------------------------------------------------
primes up to 10000: 1229 found
first 15: 2 3 5 7 11 13 17 19 23 29 31 37 41 43 47
sorted: 1 4 8 12 17 21 30 37 44 55 66 73 82 91 99
12! = 479001600
```

The RV32M ops are checked against an independent reference by differential
fuzzing (see the sibling `riscv-difftest/` approach); MULH/MULHSU/MULHU compute
the 64-bit product's high word with a 16-bit-split schoolbook multiply so no
intermediate exceeds the interpreter's 63-bit integer.

## Running

Needs a bare-metal RISC-V toolchain and the Mere compiler + clang:

```sh
brew install riscv64-elf-gcc          # riscv64-elf-{gcc,objcopy}
MERE=/path/to/mere sh run.sh
```

`run.sh` builds the emulator once (C backend), then for each program compiles
it (`-march=rv32im -mabi=ilp32 -nostdlib -lgcc`, linked at address 0 by
[`link.ld`](link.ld)), `objcopy`s it to `prog.bin`, and runs it. Point
`RISCV_GCC` / `RISCV_OBJCOPY` at your toolchain if the names differ.

Swap in your own C — keep it freestanding (no libc beyond the two syscalls) and
within RV32IM — and it runs just the same.
