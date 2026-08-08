# RV32IM throughput benchmark

How fast does the CPU emulator — itself a program written in Mere — actually
run? [`bench.c`](bench.c) is a fixed compute kernel (a xorshift32 PRNG stepped
3,000,000 times, accumulating a checksum: pure shift/xor/add, ~27 million RV32IM
instructions). [`rv32i_bench.mere`](rv32i_bench.mere) is the RV32IM core with a
drive loop that counts executed instructions, so dividing the count by the
wall-clock time gives the emulator's throughput in MIPS.

Measured on an Apple-silicon laptop:

| Mere backend | time (27.0M instrs) | throughput |
|--------------|--------------------:|-----------:|
| **C** | ~0.14 s | **~200 MIPS** |
| **LLVM** | ~0.58 s | **~47 MIPS** |
| interpreter | (does not finish in minutes) | ~10⁴× slower |

The interesting result is that Mere's **C backend is ~4× faster than its LLVM
backend** on this tight decode-execute loop, and both are compiled native code
running orders of magnitude past the tree-walking interpreter (which is fine for
the small test ROMs but impractical for tens of millions of instructions). This
is a performance data point on Mere itself, surfaced by dogfooding — the
emulators had only ever been checked for correctness before.

## Running

```sh
brew install riscv64-elf-gcc          # riscv64-elf-{gcc,objcopy}
MERE=/path/to/mere sh run.sh
```

`run.sh` compiles `bench.c` to RV32IM, builds the counting emulator through the
C and LLVM backends, times each, and prints MIPS. Adjust the iteration count in
`bench.c` to taste.
