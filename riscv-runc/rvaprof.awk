# rvaprof.awk -- fold an `aprof` run of rvrun64 into functions: where the
# guest's bytes were allocated.
#
#   mere -rv64g --ram 256 prog.mere > prog.map      # the debug map
#   ./rvrun64 256 aprof -- args 2> aprof.txt
#   awk -f rvaprof.awk prog.map aprof.txt | head -30
#
# Each rise of gp is charged to the nearest function symbol at or below the PC
# that made it (labels starting with '.' are local and skipped). A Mere guest
# that copies into an arena moves gp there and back (__acopy_*), and those
# moves are counted too: read the rows below them. The map must come from the
# same compiler and flags as the binary.
FNR == NR {
  if ($1 == "S" && substr($3, 1, 1) != ".") { n++; addr[n] = $2 + 0; name[n] = $3 }
  next
}
$1 == "rvaprof" {
  pc = $2 + 0; c = $3 + 0; total += c
  lo = 1; hi = n; k = 0
  while (lo <= hi) { mid = int((lo + hi) / 2); if (addr[mid] <= pc) { k = mid; lo = mid + 1 } else hi = mid - 1 }
  fn = (k > 0) ? name[k] : "?"
  by[fn] += c
}
END {
  if (total == 0) { print "rvaprof: no allocations (was the emulator run with `aprof`?)"; exit 1 }
  printf "%d bytes allocated\n", total
  for (f in by) printf "%6.2f%%  %s\n", 100 * by[f] / total, f | "sort -rn"
}
