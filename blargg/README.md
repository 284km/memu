# Blargg cpu_instrs — Game Boy CPU conformance

[`gb_cpu_instrs.mere`](gb_cpu_instrs.mere) is the complete Sharp LR35902 core
run against **Blargg's `cpu_instrs`** test ROMs — the de-facto conformance
suite for the Game Boy CPU. Each test prints its name and `Passed` / `Failed`
over the serial port (`$FF01`/`$FF02`), which the harness captures and prints.

The Mere core passes **10 of the 11** tests — every CPU-instruction test —
on the interpreter, C, and LLVM backends:

| Test ROM | Result |
|----------|--------|
| 01-special | Passed |
| 02-interrupts | *out of scope* — needs the interrupt/timer hardware (see below) |
| 03-op sp,hl | Passed |
| 04-op r,imm | Passed |
| 05-op rp | Passed |
| 06-ld r,r | Passed |
| 07-jr,jp,call,ret,rst | Passed |
| 08-misc instrs | Passed |
| 09-op r,r | Passed |
| 10-bit ops | Passed |
| 11-op a,(hl) | Passed |

`02-interrupts` is intentionally not implemented: it tests the interrupt
controller and timer (IME/IE/IF, the `HALT` wake, timer-driven `IF` bits),
which is machine hardware rather than instruction semantics — the same way the
6502's decimal mode was the last piece of instruction behaviour, interrupts are
the next layer *beyond* it. Here `HALT` is a no-op and no interrupts fire.

## Running

The Blargg ROMs are not redistributed here. Fetch them and run the suite:

```sh
MERE=/path/to/mere sh run.sh
```

`run.sh` downloads the individual `cpu_instrs` ROMs, compiles the core once
through the C backend, and runs each ROM, printing the captured result. To run
a single ROM by hand, copy it to `rom.gb` in this directory and:

```sh
mere -c gb_cpu_instrs.mere > gb.c && clang -O2 gb.c -o gb && ./gb
```

## Relationship to `../gameboy.mere`

[`gameboy.mere`](../gameboy.mere) in the repo root is the compact teaching rung
of the ladder. This directory holds the *complete*, conformance-verified core.
