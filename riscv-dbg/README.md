# A source-level, time-travelling debugger

`mere -rv` compiles a Mere program to RV32IM machine code. This runs one on the
RV32I core, stopping at **source lines**, and steps **backwards**.

```sh
MERE=/path/to/mere sh run.sh          # a scripted session on demo.mere
MERE=/path/to/mere sh run.sh -i       # the same program, interactively
```

```
(rvdbg) b 6
  breakpoint at line 6 (0x5f0)
(rvdbg) r
pc 0x5f0  u_fact  line 6  [.else2]
  6 |   else n * fact (n - 1);
(rvdbg) bt
  #0 u_fact line 6  (pc 0x5f0)
  #1 u_fact line 6  (pc 0x60c)
  #2 __main line 18  (pc 0x4a0)
  #3 _start line 0  (pc 0x18)
(rvdbg) S
pc 0x5e4  u_fact  line 5  [u_fact]
  5 |   if n <= 1 then 1
```

## Why it exists

Every hard bug in the bare-metal work — a kernel, a scheduler, a syscall
boundary — was found by instrumenting the plain emulator by hand: a ring buffer
of program counters here, a store watchpoint on a save area there, a register
dump at trap entry. Ten different instruments, written and thrown away. This is
that instrumentation, kept, and pointed at source lines instead of addresses.

The bug that took longest (a `region` rollback freeing memory another task was
still using) would have been minutes of work with `S`: stop in the task that
died, walk backwards, watch the heap pointer move the wrong way.

## The two halves

`mere -rvg` emits a **debug map** beside the binary. The binary has no header to
hold debug information — this backend emits code and nothing else — so the map is
a text sidecar, one record per line, addresses ascending:

```
S <addr> <name>                                 every label
F <addr> <name> fsz= ra= fp= params= line=      a function and its frame
L <addr> <line> <col>                           the statement starting here
```

The compiler emits it from the same item list it assembles, so `-rv` and `-rvg`
agree by construction: the map describes the bytes that actually run, and there is
no separate debug build to drift.

Frame layout is uniform on that backend (`[overflow][saved s-regs][fp][ra]`), so
three numbers describe it completely — which is why a backtrace here is two loads
per frame and no guessing.

## Stepping backwards

Not replay from a snapshot: the debugger keeps an **undo log**, one fixed-size
record per instruction, and going back applies the inverse of the last one.

An RV32I instruction changes at most one register and writes at most four bytes;
a trap also writes a handful of CSRs. So a record holds the PC it ran at, the
register it wrote with that register's previous value, and up to six
(place, previous value) pairs — where a negative place means a CSR index rather
than an address, which lets one record cover both kinds of state.

That makes reverse stepping **exact**, and it is tested as such: run forward N
instructions and back N, and every register and a checksum of the heap come back
to what they were. It also means you can step backwards *across a trap*, out of
an interrupt handler and onto the line the timer interrupted.

Two honest limits:

- The log is a ring buffer (200k records). Beyond that the past is gone.
- A byte written to a device is not undoable — it has already left the machine.
  Registers, RAM and CSRs come back; a character printed to the UART does not.
- If a single instruction ever changes more state than one record holds, the
  record is **poisoned** rather than truncated, and `I` refuses to cross it. A
  debugger that lies about the past is worse than one that admits a wall.

## Commands

| | |
|---|---|
| `b <line>` | breakpoint at a source line |
| `bl` | list breakpoints |
| `r` / `c` | run to a breakpoint or the end |
| `s` / `i` | step one source line / one instruction |
| `S` / `I` | step **back** one source line / one instruction |
| `w` | where am I (pc, function, source line) |
| `bt` | backtrace |
| `p` | registers |
| `x <addr>` | read a word |
| `k <addr>` | checksum 4KB — "did anything in here move?" |
| `n` | instructions retired |
| `q` | quit |

`s` lands on the next *statement*: addresses with no line record — a prologue, a
runtime helper — are passed through rather than stopped at.

## Notes

- It loads `prog.bin`, `prog.map` and `prog.mere` from its own directory, plus
  `user.bin` at 8MB if present (a kernel's user process debugs the same way).
- `--bare` programs work: breakpoints inside a trap handler, and a backtrace that
  shows `__trap_entry` beneath it.
- The guest gets **no** UART receive side here. Stdin belongs to the operator,
  which is also what makes a session scriptable — pipe commands in, as `run.sh`
  does.
- The core is the one from [`../riscv-runc`](../riscv-runc), with every state
  change routed through the undo log.
