#!/usr/bin/env python3
# Differential tester for the Mere RV32I core (rv32i_core.mere).
#
# An INDEPENDENT Python RV32I reference executes randomly-generated straight-
# line programs — the R/I/U-type ALU ops (arithmetic, logic, shifts, signed and
# unsigned compares, sign-extended immediates, LUI/AUIPC) plus loads and stores
# (LW/LB/LBU/SW/SB) into a reserved scratch region at $1000 (base register x9).
# The Mere core runs the same program (prog.bin) and dumps x0..x31 plus 16
# scratch words; the two are compared. Any divergence localizes a bug that
# hand-written tests would miss. This substitutes for the official riscv-tests,
# which require a RISC-V toolchain to assemble.
#
#   python3 difftest.py <mere-binary> <workdir> [nseeds] [ninstrs]
import random, struct, subprocess, sys, os

MASK = 0xFFFFFFFF
def u32(x): return x & MASK
def s32(x):
    x &= MASK
    return x - (1 << 32) if x & 0x80000000 else x

def r(f7, rs2, rs1, f3, rd, op): return (f7 << 25)|(rs2 << 20)|(rs1 << 15)|(f3 << 12)|(rd << 7)|op
def itype(imm, rs1, f3, rd, op): return ((imm & 0xFFF) << 20)|(rs1 << 15)|(f3 << 12)|(rd << 7)|op
def stype(imm, rs2, rs1, f3, op):
    return (((imm >> 5) & 0x7F) << 25)|(rs2 << 20)|(rs1 << 15)|(f3 << 12)|((imm & 0x1F) << 7)|op
def utype(imm, rd, op): return ((imm & 0xFFFFF) << 12)|(rd << 7)|op

SCRATCH = 0x1000
BASE = 9   # x9 holds SCRATCH, never overwritten

def run_ref(words):
    x = [0]*32
    mem = bytearray(0x2000)   # covers program + scratch
    # load program bytes into a flat image
    pb = b''.join(struct.pack('<I', w & MASK) for w in words)
    mem[0:len(pb)] = pb
    def ld(a, n): return int.from_bytes(mem[a:a+n], 'little')
    def stb(a, n, v): mem[a:a+n] = (v & ((1 << (8*n)) - 1)).to_bytes(n, 'little')
    for idx, w in enumerate(words):
        pc = idx*4
        op = w & 0x7F; rd = (w>>7)&0x1F; f3=(w>>12)&7; rs1=(w>>15)&0x1F; rs2=(w>>20)&0x1F; f7=(w>>25)&0x7F
        a, b = x[rs1], x[rs2]
        def wr(v):
            if rd != 0: x[rd] = u32(v)
        if op == 0x37:   wr(w & 0xFFFFF000)
        elif op == 0x17: wr(u32(pc + (w & 0xFFFFF000)))
        elif op == 0x03:                                     # loads
            imm = (w >> 20); imm = imm - (1<<12) if imm & 0x800 else imm
            addr = u32(a + imm)
            if f3 == 2:   wr(ld(addr, 4))                    # LW
            elif f3 == 0: v = ld(addr,1); wr(v - 256 if v & 0x80 else v)   # LB
            elif f3 == 4: wr(ld(addr, 1))                    # LBU
        elif op == 0x23:                                     # stores
            imm = ((w>>25)<<5)|((w>>7)&0x1F); imm = imm - (1<<12) if imm & 0x800 else imm
            addr = u32(a + imm)
            if f3 == 2:   stb(addr, 4, b)                    # SW
            elif f3 == 0: stb(addr, 1, b)                    # SB
        elif op == 0x13:
            imm = (w >> 20); imm = imm - (1<<12) if imm & 0x800 else imm
            if f3==0: wr(a+imm)
            elif f3==2: wr(1 if s32(a) < imm else 0)
            elif f3==3: wr(1 if u32(a) < u32(imm) else 0)
            elif f3==4: wr(a^imm)
            elif f3==6: wr(a|imm)
            elif f3==7: wr(a&imm)
            elif f3==1: wr(u32(a) << (rs2 & 31))
            elif f3==5: wr(u32(a) >> (rs2&31) if f7==0 else u32(s32(a) >> (rs2&31)))
        elif op == 0x33:
            sh = b & 31
            if f3==0: wr(a-b if f7==0x20 else a+b)
            elif f3==1: wr(u32(a) << sh)
            elif f3==2: wr(1 if s32(a) < s32(b) else 0)
            elif f3==3: wr(1 if u32(a) < u32(b) else 0)
            elif f3==4: wr(a^b)
            elif f3==5: wr(u32(a) >> sh if f7==0 else u32(s32(a) >> sh))
            elif f3==6: wr(a|b)
            elif f3==7: wr(a&b)
    regs = [u32(v) for v in x]
    scratch = [ld(SCRATCH + i*4, 4) for i in range(16)]
    return regs + scratch

REGS = list(range(0, 9))   # x0..x8 for ALU; x9 reserved as scratch base
def gen(rng, k):
    ws = [utype(1, BASE, 0x37)]     # prologue: LUI x9, 1  => x9 = 0x1000
    for _ in range(k):
        kind = rng.randrange(6)
        rd = rng.choice(REGS[1:])
        rs1 = rng.choice(REGS); rs2 = rng.choice(REGS)
        if kind == 0:
            f3 = rng.randrange(8); f7 = 0x20 if (f3 in (0,5) and rng.random()<0.5) else 0
            ws.append(r(f7, rs2, rs1, f3, rd, 0x33))
        elif kind == 1:
            f3 = rng.choice([0,2,3,4,6,7]); ws.append(itype(rng.randrange(-2048,2048), rs1, f3, rd, 0x13))
        elif kind == 2:
            f3 = 1 if rng.random()<0.4 else 5; sh = rng.randrange(0,32)
            f7 = 0x20 if (f3==5 and rng.random()<0.5) else 0
            ws.append(itype((f7<<5)|sh, rs1, f3, rd, 0x13))
        elif kind == 3:
            ws.append(utype(rng.randrange(0,1<<20), rd, 0x37 if rng.random()<0.5 else 0x17))
        elif kind == 4:                                   # store to scratch
            off = rng.randrange(0, 13) * 4                # word-aligned 0..48
            f3 = rng.choice([2, 0])                       # SW / SB
            ws.append(stype(off, rng.choice(REGS), BASE, f3, 0x23))
        else:                                             # load from scratch
            off = rng.randrange(0, 13) * 4
            f3 = rng.choice([2, 0, 4])                    # LW / LB / LBU
            ws.append(itype(off, BASE, f3, rd, 0x03))
    return ws

def main():
    mere_bin, workdir = sys.argv[1], sys.argv[2]
    nseeds = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
    kins = int(sys.argv[4]) if len(sys.argv) > 4 else 60
    progpath = os.path.join(workdir, "prog.bin")
    fails = 0
    for seed in range(nseeds):
        words = gen(random.Random(seed ^ 0x5eed), kins)
        with open(progpath, "wb") as f:
            for w in words: f.write(struct.pack("<I", w & MASK))
        expected = run_ref(words)
        out = subprocess.run([mere_bin], cwd=workdir, capture_output=True, text=True).stdout
        got = [int(v) for v in out.split()][:48]    # 32 regs + 16 scratch words
        if got != expected:
            fails += 1
            print(f"MISMATCH seed={seed}")
            for j in range(48):
                if j < len(got) and got[j] != expected[j]:
                    label = f"x{j}" if j < 32 else f"mem[{(j-32)*4:#x}]"
                    print(f"  {label}: mere={got[j]} ref={expected[j]}")
            if fails >= 5: print("... stopping"); break
    if fails == 0:
        print(f"OK: {nseeds} programs x {kins} instrs (+loads/stores) — registers and scratch memory match")
    else:
        sys.exit(1)

main()
