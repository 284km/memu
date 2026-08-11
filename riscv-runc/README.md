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

## Devices

Addresses at or above `0x10000000` are device MMIO rather than RAM, so a device
address does not move when the RAM size does. One device so far:

| address | register | behaviour |
|---------|----------|-----------|
| `0x10000000` | UART data (write) | the byte goes to stdout as it happens |
| `0x10000000` | UART data (read) | the next byte of the host's stdin |
| `0x10000005` | UART line status (read) | bit 5 transmitter ready (always), bit 0 data waiting |
| `0x10008000` | CLINT mtime | a monotonic counter, one tick per instruction |
| `0x10008008` | CLINT mtimecmp | the deadline; reaching it raises a timer interrupt |

The receive side keeps one byte of lookahead, because a guest asks "is anything
waiting?" before it asks "what is it?". Finding out uses Mere's `stdin_byte`,
which polls without blocking — `read_key` would stop the whole machine until a
key arrived, which is no use to a CPU that also has timers to service.

`0x10000000` is where QEMU's `virt` machine puts UART0, so a guest driver
written against it is not learning a private convention. Unlike the `ecall`
write syscall — which buffers until the guest halts — the UART streams, which
is what a guest that never exits needs.

`mere -rv --bare` compiles a Mere program that drives this UART directly,
through a window capability rather than any host syscall — in both directions:

```sh
printf 'hello\nq' | ./rvrun     # against the Mere repo's riscv_bare_echo example
```

## CSRs, traps and the timer

The machine's control-and-status registers are a flat 4096-slot file, so
`csrrw` / `csrrs` / `csrrc` and their immediate forms work on any number, and
`mret` returns to `mepc` while restoring the interrupt-enable bit from `MPIE`.
`wfi` is a nop.

Traps vector to `mtvec` (direct mode) with the faulting PC in `mepc`, the reason
in `mcause` and the offending value in `mtval`, and `MIE` moved into `MPIE` so
`mret` can put it back:

| `mcause` | when |
|----------|------|
| 2 | an instruction this core does not implement |
| 5 / 7 | a load / store past the end of RAM |
| `0x80000007` | the timer: `mtime` reached `mtimecmp`, with `MIE` and `MTIE` set |

A guest with `mtvec` still zero has nowhere to go, so it halts — as it did
before traps existed, rather than jumping to address 0 and overwriting itself.
The access faults are the interesting ones for anyone writing a guest: an
address past RAM used to take the *emulator* down with a Mere "index out of
bounds", reporting the host's problem instead of the guest's.

`mtime` advances once per instruction. That is a clock in units of work done,
which is what a deterministic emulator can honestly offer, and it is enough for
a scheduler tick. The interrupt is taken between instructions — the only point
where the machine is in a consistent state to vector away from.

The Mere side of this is `set_trap_handler`, which takes an ordinary closure:
see the main repo's `examples/riscv_bare_timer.mere`, where a machine interrupts
itself and a Mere handler services the timer while the main loop just spins.

## Running your own

The emulator takes an optional RAM size in MB (`./rvrun 20`), defaulting to 8.
It matters for `mere -rv` output, whose stack starts at the top of RAM: see
[`../riscv-mere`](../riscv-mere). There is no instruction budget — the guest
runs until it halts, so Ctrl-C is the way out of a runaway program.
