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
compiles with `mere -rv` to a ~300 KB RV32IM binary and runs on this emulator,
producing WAT output byte-identical to the native interpreter. The Mere
compiler compiling Mere programs, on the Mere CPU.

It needs more than the default 8 MB — the compiler's heap peaks somewhere
between 14 and 18 MB, and `mere -rv`'s allocator never reclaims — so both
sides have to be told about it:

```sh
mere -rv --ram 20 driver.mere > prog.bin   # stack starts at the top of 20 MB
./rvrun 20                                 # emulator sized to match
```

Give the emulator a smaller address space than the binary was built for and it
will run off the end of memory immediately; give the binary less RAM than it
needs and it stops with `mere: out of memory (heap reached the stack)`.

## How the binary is laid out

`mere -rv` emits code at address 0 and lays out the rest from the RAM size —
8 MB unless `--ram` says otherwise, which is the default this emulator uses
when given no argument:

```
0x000000  code (starts at _start)
0x200000  globals + heap  (grows up)
   ...
          stack  (grows down from 128 KB below the top of RAM)
          print scratch buffer, framebuffer, keys  (the reserved top 128 KB)
```

The heap and the stack grow toward each other with nothing in between; every
allocation checks for the collision and stops with a message rather than
overwriting a live frame.

Values are 32-bit words (an int, or a pointer into the heap); tuples, ADTs,
records, strings, closures, and Vec/Map are heap blocks. A small runtime
(`_start`, `print_int`, string/heap helpers) is emitted ahead of the program.

## Notes

- Requires the `mere` compiler (set `$MERE`) and `clang` (to build the
  emulator through Mere's C backend).
- The emulator services the same tiny syscall ABI as `../riscv-runc`
  (`ecall` a7=64 write, a7=93 exit).
