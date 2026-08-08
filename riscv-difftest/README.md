# RV32I differential test

The official [riscv-tests](https://github.com/riscv-software-src/riscv-tests)
need a RISC-V toolchain to assemble, so instead the RV32I core is validated by
**differential testing against an independent reference**: an independent
Python RV32I implementation ([`difftest.py`](difftest.py)) executes thousands
of randomly-generated straight-line programs, [`rv32i_core.mere`](rv32i_core.mere)
runs the same programs, and their full machine state (all 32 registers plus a
scratch memory region) is compared. Random fuzzing explores the state space far
past any hand-written test, and because the two implementations are written
independently, a shared blind spot is unlikely; any divergence pins the bug to
one register or memory word.

The generated programs cover the R/I/U-type ALU ops — arithmetic, logic, the
three shifts (including arithmetic `sra`), signed and unsigned comparison,
sign-extended immediates, and `LUI`/`AUIPC` — plus loads and stores
(`LW`/`LB`/`LBU`/`SW`/`SB`). Control flow (branches, `JAL`/`JALR`) is covered by
the deterministic parity lock in the Mere repo instead, so the generated
programs stay straight-line and directly comparable.

The Mere core matches the reference on every program, on both the C and LLVM
backends (e.g. 3000 programs × 80 instructions ≈ 240k instructions for the ALU
core, plus loads/stores).

## Running

```sh
MERE=/path/to/mere sh run.sh
```

`run.sh` compiles the core once through the C backend and runs the differential
battery. To run more:

```sh
mere -c rv32i_core.mere > rv.c && clang -O2 rv.c -o rvdump
python3 difftest.py ./rvdump . 3000 80      # 3000 programs, 80 instrs each
```

A clean run prints `OK: ... registers and scratch memory match`; a divergence
prints the seed and the differing registers/memory.

## Relationship to `../riscv.mere`

[`riscv.mere`](../riscv.mere) in the repo root is the ladder rung — the same
RV32I core with a small hand-assembled demo program. This directory reuses that
core behind a file-loading register/memory dump so it can be fuzzed.
