# A fantasy console on the Mere RISC-V CPU

A Mere program draws pixels; this RV32I emulator renders the framebuffer. The
program is compiled straight to RV32IM by [Mere](https://github.com/merelang/mere)'s
`mere -rv` backend — no C, no external assembler — and run on the emulator
from [`../riscv-runc`](../riscv-runc), extended to dump the framebuffer.

```sh
MERE=/path/to/mere sh run.sh
```

`mere -rv` lowers `fb_set x y v` (declared `extern fn fb_set: int -> int -> int
-> unit;`) to a byte store into a **64×32 framebuffer at 0x7F8000** (above the
stack, in the 8 MB address space). After the program halts,
[`rv32i_console.mere`](rv32i_console.mere) reads that region and prints it as a
shade ramp (`" .:-=+*#"`). [`console.mere`](console.mere) draws a bordered box,
an X, and a filled disc:

```
:..............................................................:
. :                                                          : .
   ... (border + diagonals) ...
.                 :----------#######----------                 .
.                -------#################-------               .
.               ------#####################------              .
.              -----#########################-----             .
   ... a filled disc with a ring ...
.:............................................................:.
```

This is the headless foundation. A browser version would render the same
framebuffer region to a `<canvas>` (reusing the DOM FFI the Game Boy playground
uses) and feed input back through a memory-mapped register — a natural next
step.

## Notes
- Requires the `mere` compiler (`$MERE`) and `clang`.
- Graphics-only: the framebuffer is dumped only if the program wrote to it, so
  the emulator still runs ordinary (text) `mere -rv` programs unchanged.
