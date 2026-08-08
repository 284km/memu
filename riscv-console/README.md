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

## Interactive: input + per-frame presentation

The console also has input and a frame loop. Two more externs complete the
hardware contract, both lowered by `mere -rv`:

- `key n` — read the held state of button `n` (0=right, 1=left, 2=up,
  3=down): a byte load from an input register at `0x7F9000 + n`, which the host
  refreshes each frame.
- `present ()` — end the frame and yield to the host via `ecall a7=100`. The
  CPU resumes on the *next* instruction next frame, so the cartridge's main
  loop is a coroutine — the player's position lives on the RISC-V call stack,
  not in any global.

[`game.mere`](game.mere) is an arrow-key-playable cartridge (a block you move
around a field). [`rv32i_play.mere`](rv32i_play.mere) drives it headlessly with
a scripted input sequence, dumping the framebuffer after each frame so the
player is seen to move — and clamp against the wall — without a browser:

```sh
MERE=/path/to/mere sh play.sh
```

### In the browser

The same emulator, compiled to WebAssembly and wired to a `<canvas>` (ROM via
`dom_rom_byte`, keys via `dom_key_held`, framebuffer blitted per frame), runs
live at **merelang.org/playground/rvconsole.html** — a Mere-authored RV32IM CPU
running a Mere-authored cartridge, in the browser.

## Notes
- Requires the `mere` compiler (`$MERE`) and `clang`.
- Graphics-only: the framebuffer is dumped only if the program wrote to it, so
  the emulator still runs ordinary (text) `mere -rv` programs unchanged.
- `rv32i_console.mere` runs a one-shot cartridge to completion;
  `rv32i_play.mere` adds the `key`/`present` frame loop.
