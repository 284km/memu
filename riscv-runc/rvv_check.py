#!/usr/bin/env python3
"""rvv_check.py -- directed tests for the RVV subset in rv32i_run.mere / rv64i_run.mere.

Each test is a small bare-metal program (QEMU virt layout, loaded at 0x80000000)
that loads sixteen-byte operands with vle8.v, runs one vector operation, stores
the result with vse8.v, writes it to the UART byte by byte, and stops through the
test finisher. Three parties compute the sixteen bytes: this file's Python model
of the instruction, the memu core, and -- when qemu-system-riscv32 is on PATH --
QEMU with `-cpu rv32,v=true,vlen=128`. All three must agree, byte for byte.

  python3 rvv_check.py <path to compiled rv32i_run> [<compiled rv64i_run>]
"""
import os, shutil, subprocess, sys, tempfile

BASE = 0x80000000
def R(f7, rs2, rs1, f3, rd, op): return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def I(imm, rs1, f3, rd, op): return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def Sw(imm, rs2, rs1, f3, op):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op
def U(imm20, rd, op): return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op
def lui(rd, imm20): return U(imm20, rd, 0x37)
def addi(rd, rs1, imm): return I(imm, rs1, 0, rd, 0x13)
def lb(rd, rs1, imm): return I(imm, rs1, 0, rd, 0x03)
def sb(rs2, rs1, imm): return Sw(imm, rs2, rs1, 0, 0x23)
def sh(rs2, rs1, imm): return Sw(imm, rs2, rs1, 1, 0x23)
def sw(rs2, rs1, imm): return Sw(imm, rs2, rs1, 2, 0x23)
# vector
def vsetivli(rd, uimm, zimm): return (1 << 31) | (1 << 30) | ((zimm & 0x3FF) << 20) | ((uimm & 0x1F) << 15) | (7 << 12) | (rd << 7) | 0x57
def vle8(vd, rs1): return (1 << 25) | (rs1 << 15) | (vd << 7) | 0x07
def vse8(vs3, rs1): return (1 << 25) | (rs1 << 15) | (vs3 << 7) | 0x27
def opv(f6, vm, vs2, vs1, f3, vd): return (f6 << 26) | (vm << 25) | (vs2 << 20) | (vs1 << 15) | (f3 << 12) | (vd << 7) | 0x57
def vv(f6, vd, vs2, vs1, vm=1): return opv(f6, vm, vs2, vs1, 0, vd)
def vx(f6, vd, vs2, rs1, vm=1): return opv(f6, vm, vs2, rs1, 4, vd)
def vi(f6, vd, vs2, imm5, vm=1): return opv(f6, vm, vs2, imm5 & 0x1F, 3, vd)
def mvv(f6, vd, vs2, vs1): return opv(f6, 1, vs2, vs1, 2, vd)

X10, X11, X12, X13, X14, X15, X16, X6, X7, X8 = 10, 11, 12, 13, 14, 15, 16, 6, 7, 8
def csrrs(rd, csr, rs1): return I(csr, rs1, 2, rd, 0x73)
def program(body_words, out_bytes=16, rv64=False):
    """prologue (addresses, mstatus.VS on), the test body (result in memory at x13),
    epilogue (UART, finisher). On RV64 `lui 0x80001` sign-extends, so the data base is
    zero-extended with a shift pair (shamt 32 is RV64-only, hence the flag)."""
    ws = [lui(X10, 0x80001)]
    if rv64: ws += [I(32, X10, 1, X10, 0x13), I(32, X10, 5, X10, 0x13)]     # slli 32; srli 32
    ws += [addi(X11, X10, 0x10), addi(X12, X10, 0x20), addi(X13, X10, 0x30),
          lui(X14, 0x10000), lui(X15, 0x100), lui(X16, 0x5), addi(X16, X16, 0x555),
          # mstatus.VS = Initial (bit 9): a real machine (QEMU) traps every vector
          # instruction while it is Off; memu has no such state and the write is harmless
          addi(X6, 0, 0x200), csrrs(0, 0x300, X6),
          vsetivli(5, 16, 0)]                                    # e8, m1, vl = 16
    ws += body_words
    for i in range(out_bytes):
        ws += [lb(X8, X13, i), sb(X8, X14, 0)]
    ws += [sw(X16, X15, 0)]                                       # finisher: 0x5555 = pass
    return ws

A = bytes([0x00, 0x01, 0x7f, 0x80, 0xff, 0x10, 0x20, 0x30, 0x40, 0x55, 0xaa, 0x0f, 0xf0, 0x33, 0xcc, 0x99])
B = bytes([0x01, 0x01, 0x7f, 0x7f, 0x01, 0x10, 0x21, 0x30, 0x3f, 0x55, 0xab, 0x0f, 0xf1, 0x33, 0xcd, 0x98])
IDX = bytes([15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0])
IDX_BIG = bytes([0, 16, 1, 17, 2, 200, 3, 31, 4, 255, 5, 32, 6, 15, 7, 128])

def sat_sub(a, b): return a - b if a > b else 0
tests = []
def t(name, body, expect, out_bytes=16, data=None): tests.append((name, body, expect, out_bytes, data or {}))
t("vadd.vv",   [vle8(1, X10), vle8(2, X11), vv(0, 3, 1, 2), vse8(3, X13)],   bytes((a + b) & 0xFF for a, b in zip(A, B)))
t("vsub.vv",   [vle8(1, X10), vle8(2, X11), vv(2, 3, 1, 2), vse8(3, X13)],   bytes((a - b) & 0xFF for a, b in zip(A, B)))
t("vand.vv",   [vle8(1, X10), vle8(2, X11), vv(9, 3, 1, 2), vse8(3, X13)],   bytes(a & b for a, b in zip(A, B)))
t("vor.vv",    [vle8(1, X10), vle8(2, X11), vv(10, 3, 1, 2), vse8(3, X13)],  bytes(a | b for a, b in zip(A, B)))
t("vxor.vv",   [vle8(1, X10), vle8(2, X11), vv(11, 3, 1, 2), vse8(3, X13)],  bytes(a ^ b for a, b in zip(A, B)))
t("vssubu.vv", [vle8(1, X10), vle8(2, X11), vv(34, 3, 1, 2), vse8(3, X13)],  bytes(sat_sub(a, b) for a, b in zip(A, B)))
t("vsrl.vx 4", [vle8(1, X10), addi(X6, 0, 4), vx(40, 3, 1, X6), vse8(3, X13)], bytes(a >> 4 for a in A))
t("vmseq+vmerge", [vle8(1, X10), vle8(2, X11), vv(24, 0, 1, 2), vi(23, 4, 0, 0), vi(23, 3, 4, -1, vm=0), vse8(3, X13)],
  bytes(0xFF if a == b else 0 for a, b in zip(A, B)))
t("vrgather.vv reverse", [vle8(1, X10), vle8(2, X12), vv(12, 3, 1, 2), vse8(3, X13)], bytes(A[i] for i in IDX), data={0x20: IDX})
t("vrgather.vv big idx -> 0", [vle8(1, X10), vle8(2, X12), vv(12, 3, 1, 2), vse8(3, X13)],
  bytes(A[i] if i < 16 else 0 for i in IDX_BIG), data={0x20: IDX_BIG})
t("shift_in 3 (slidedown 13 + slideup 3)", [vle8(1, X10), vle8(2, X11), vi(15, 3, 1, 13), vi(14, 3, 2, 3), vse8(3, X13)],
  bytes(list(A[13:]) + list(B[:13])))
t("vwredsumu.vs -> e16", [vle8(1, X10), vi(23, 5, 0, 0), vv(48, 3, 1, 5), vsetivli(5, 8, 8), mvv(16, X7, 3, 0), sh(X7, X13, 0)],
  (sum(A) & 0xFFFF).to_bytes(2, "little"), out_bytes=2)
t("vredor.vs", [vle8(1, X10), vi(23, 5, 0, 0), mvv(2, 3, 1, 5), mvv(16, X7, 3, 0), sb(X7, X13, 0)],
  bytes([eval("|".join(str(a) for a in A))]), out_bytes=1)
t("vmv.v.x splat", [addi(X6, 0, 0x5a), vx(23, 3, 0, X6), vse8(3, X13)], bytes([0x5a] * 16))

def build(body, data, rv64=False):
    ws = program(body, 16, rv64=rv64)
    img = bytearray(0x1000 + 0x40)
    for i, w in enumerate(ws): img[4 * i:4 * i + 4] = w.to_bytes(4, "little")
    img[0x1000:0x1010] = A; img[0x1010:0x1020] = B
    for off, b in data.items(): img[0x1000 + off:0x1000 + off + len(b)] = b
    return bytes(img)

def run_memu(core, img, out_bytes):
    with tempfile.TemporaryDirectory() as d:
        open(os.path.join(d, "prog.bin"), "wb").write(img)
        p = subprocess.run([core, "8", "virt"], cwd=d, capture_output=True, timeout=60)
        return p.stdout[:out_bytes], p.stderr.decode(errors="replace")

def run_qemu(img, out_bytes):
    q = shutil.which("qemu-system-riscv32")
    if not q: return None, "no qemu-system-riscv32"
    with tempfile.TemporaryDirectory() as d:
        f = os.path.join(d, "prog.bin"); open(f, "wb").write(img)
        try:
            p = subprocess.run([q, "-M", "virt", "-bios", "none", "-nographic", "-no-reboot",
                                "-cpu", "rv32,v=true,vlen=128,elen=64", "-kernel", f],
                               capture_output=True, timeout=30)
        except subprocess.TimeoutExpired:
            return b"", "qemu timed out"
        return p.stdout[:out_bytes], p.stderr.decode(errors="replace")

def main():
    cores = sys.argv[1:]
    if not cores: print(__doc__); sys.exit(2)
    fails = 0; ran = 0
    for name, body, expect, nout, data in tests:
        img = build(body, data)
        img64 = build(body, data, rv64=True)
        # the epilogue writes 16 bytes; compare only what the test defines
        parties = {}
        for core in cores:
            is64 = "64" in os.path.basename(core)
            got, err = run_memu(core, img64 if is64 else img, nout)
            parties[os.path.basename(core)] = (got, err)
        qgot, qerr = run_qemu(img, nout)
        if qgot is not None: parties["qemu"] = (qgot, qerr)
        ok = all(g == expect for g, _ in parties.values())
        ran += 1
        if ok:
            print(f"  ok    {name:38s} {expect.hex()}  ({', '.join(parties)})")
        else:
            fails += 1
            print(f"  FAIL  {name}")
            print(f"        model  {expect.hex()}")
            for who, (g, err) in parties.items():
                print(f"        {who:12s} {g.hex()}  {err.strip()[:120]}")
    print(f"rvv_check: {ran - fails} ok, {fails} failed, {ran} tests; parties: " + ", ".join(parties))
    sys.exit(1 if fails or ran == 0 else 0)

if __name__ == "__main__": main()
