# rvprof.awk -- fold a `prof` run of rvrun64 into functions.
#
#   mere -rv64g --ram 256 prog.mere > prog.map      # the debug map
#   ./rvrun64 256 prof -- args 2> prof.txt
#   awk -f rvprof.awk prog.map prof.txt | head -30
#
# Each sample is charged to the nearest function symbol at or below its PC
# (labels starting with '.' are local and skipped). The map must come from the
# same compiler and flags as the binary.
FNR == NR {
  if ($1 == "S" && substr($3, 1, 1) != ".") { n++; addr[n] = $2 + 0; name[n] = $3 }
  next
}
$1 == "rvprof" {
  pc = $2 + 0; c = $3 + 0; total += c
  lo = 1; hi = n; k = 0
  while (lo <= hi) { mid = int((lo + hi) / 2); if (addr[mid] <= pc) { k = mid; lo = mid + 1 } else hi = mid - 1 }
  fn = (k > 0) ? name[k] : "?"
  by[fn] += c
}
END {
  if (total == 0) { print "rvprof: no samples (was the emulator run with `prof`?)"; exit 1 }
  printf "%d samples, ~%d instructions\n", total, total * 997
  for (f in by) printf "%6.2f%%  %s\n", 100 * by[f] / total, f | "sort -rn"
}
