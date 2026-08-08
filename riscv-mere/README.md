# Mere on RISC-V — the language running on its own CPU

The [Mere](https://github.com/merelang/mere) compiler has a fifth backend,
`mere -rv`, that lowers a Mere program **straight to a flat RV32IM binary** —
no external assembler, no linker. This directory runs those binaries on the
Mere-written RISC-V emulator in [`../riscv-runc`](../riscv-runc), so a
Mere-authored language runs on a Mere-authored CPU.

```sh
MERE=/path/to/mere sh run.sh
```

```
=== demo.mere ===
fib(20)    = 6765
10!        = 3628800
sum 1..4   = 10
twice inc  = 42
------------------------
compiled by `mere -rv`, run on the Mere RISC-V CPU.
```

[`demo.mere`](demo.mere) exercises integers and recursion, closures and
higher-order functions, a hand-rolled `ilist` ADT with pattern matching, and
strings — all compiled to RV32IM and run on the emulator.

## The self-hosted compiler runs here too

The headline: the Mere **self-hosted compiler** (lexer + parser + type checker
+ WebAssembly codegen, all written in Mere, in the main repo's `contrib/`)
compiles with `mere -rv` to a ~380 KB RV32IM binary and runs on this emulator,
producing WAT output byte-identical to the native interpreter. The Mere
compiler compiling Mere programs, on the Mere CPU.

## How the binary is laid out

`mere -rv` emits code at address 0 and uses this memory map (which is why the
emulator has an 8 MB address space):

```
0x000000  code (starts at _start)
0x200000  globals + heap  (grows up)
   ...
0x7E0000  stack  (grows down)
0x7F0000  print scratch buffer
```

Values are 32-bit words (an int, or a pointer into the heap); tuples, ADTs,
records, strings, closures, and Vec/Map are heap blocks. A small runtime
(`_start`, `print_int`, string/heap helpers) is emitted ahead of the program.

## Notes

- Requires the `mere` compiler (set `$MERE`) and `clang` (to build the
  emulator through Mere's C backend).
- The emulator services the same tiny syscall ABI as `../riscv-runc`
  (`ecall` a7=64 write, a7=93 exit).
