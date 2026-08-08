# Running real compiled software on the RV32I core

This runs an actual C program — compiled by `gcc` to RISC-V — on the CPU
emulator written in Mere. [`rv32i_run.mere`](rv32i_run.mere) is the RV32I core
(see [`../riscv.mere`](../riscv.mere)) with a flat-binary loader and a minimal
syscall ABI on `ecall`:

| `a7` | syscall | effect |
|------|---------|--------|
| 64 | `write(fd, buf, len)` | copy `len` bytes from `buf` to stdout |
| 93 | `exit(code)` | halt |

[`hello.c`](hello.c) is a freestanding program (its own `_start`, no libc)
that prints a line, sums 1..100, and computes `fib(20)` — using `printf`-style
integer formatting, so it exercises `libgcc`'s software multiply/divide (RV32I
has no `M` extension). It is compiled to a flat binary and executed by the Mere
emulator, which produces:

```
Hello from C, compiled to RISC-V RV32I, running on a Mere emulator!
sum 1..100 = 5050
fib(20)    = 6765
```

Same output on the interpreter, C, and LLVM backends.

## Running

Needs a bare-metal RISC-V toolchain and the Mere compiler + clang:

```sh
brew install riscv64-elf-gcc          # riscv64-elf-{gcc,objcopy}
MERE=/path/to/mere sh run.sh
```

`run.sh` compiles `hello.c` (`-march=rv32i -mabi=ilp32 -nostdlib -lgcc`, linked
at address 0 by [`link.ld`](link.ld)), `objcopy`s it to `prog.bin`, builds the
emulator through the C backend, and runs it. Point `RISCV_GCC` / `RISCV_OBJCOPY`
at your toolchain if the names differ.

Swap in your own C (keep it freestanding: no libc calls other than the two
syscalls, and stay within RV32I + libgcc) and it will run just the same.
