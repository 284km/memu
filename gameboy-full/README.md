# Game Boy — the full machine (in progress)

Turning the Game Boy CPU core into a complete console. This is the multi-step
"full machine" arc; each milestone adds one layer of real hardware.

**Milestone 1 — timing + interrupts (done).** [`gb_machine.mere`](gb_machine.mere)
is the complete LR35902 CPU (see [`../blargg/`](../blargg/)) plus the spine that
makes a machine tick:

- per-instruction **cycle costs** (an M-cycle table),
- the **timer** (DIV/TIMA/TMA/TAC), which requests a timer interrupt when TIMA
  overflows,
- the **interrupt controller** — IME, IE (`$FFFF`), IF (`$FF0F`), the five
  vectors — with EI's one-instruction enable delay, RETI, and a HALT that waits
  for an interrupt.

That is enough to pass **all 11** of Blargg's `cpu_instrs` tests — including
`02-interrupts`, which the CPU-only core can't — on the interpreter, C, and LLVM
backends:

```
01-special            Passed      07-jr,jp,call,ret,rst Passed
02-interrupts         Passed      08-misc instrs        Passed
03-op sp,hl           Passed      09-op r,r             Passed
04-op r,imm           Passed      10-bit ops            Passed
05-op rp              Passed      11-op a,(hl)          Passed
06-ld r,r             Passed
```

### Roadmap

| Milestone | Adds | Verified by |
|-----------|------|-------------|
| **1. timing + interrupts** ✅ | cycle table, timer, IME/IE/IF + vectors | Blargg `cpu_instrs` 11/11 |
| **2. PPU** ✅ | background → window → sprites, scanline render → framebuffer | dmg-acid2 (recognizable) |
| **3a. MBC1** ✅ | ROM bank switching ($2000-$3FFF) | combined 64 KB `cpu_instrs.gb` "Passed all tests" |
| 3b. joypad | `$FF00` input | — (needed for interactive play) |
| 4. browser | framebuffer → `<canvas>` via the `contrib/dom` FFI | a real homebrew `.gb` runs |
| 5. (optional) APU | 4 sound channels | — |

**Milestone 3a — MBC1 (done).** Both `gb_machine.mere` and `gb_ppu.mere` now
implement MBC1 ROM banking: bank 0 stays at `$0000-$3FFF` and a bank-select
write (`$2000-$3FFF`) copies the chosen bank into the `$4000-$7FFF` window. The
combined 64 KB `cpu_instrs.gb` — which the 11 individual tests are packed into,
reached by switching banks — now runs end to end and prints **"Passed all
tests"**. So the machine runs both 32 KB ROMs and larger MBC1 carts.

**Milestone 2 — PPU (done).** [`gb_ppu.mere`](gb_ppu.mere) adds the picture
processing unit on top of the machine: LCD timing (LY / VBlank), a scrolled
background, the window, and sprites (8×8/8×16, X/Y flip, OBP0/OBP1, the
behind-background priority bit), rendered scanline-by-scanline into a 160×144
framebuffer. Running mattcurrie's `dmg-acid2` PPU test ROM draws its reference
face — header text, eyes/nose/mouth, and the head outline — recognizably on the
interpreter, C, and LLVM backends. (Pixel-exact dmg-acid2 additionally wants the
10-sprites-per-line limit and X-coordinate priority — a later refinement.)

```sh
MERE=/path/to/mere sh ppu.sh     # fetches dmg-acid2 and dumps the frame as ASCII
```

## Running (milestone 1)

```sh
brew install # nothing GB-specific; just needs the Mere compiler + clang + curl
MERE=/path/to/mere sh run.sh
```

`run.sh` fetches Blargg's `cpu_instrs` individual ROMs, builds the machine
through the C backend, and runs each — expecting 11× `Passed`. ROMs are fetched,
not redistributed.
