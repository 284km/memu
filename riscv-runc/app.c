/* A bigger freestanding C program for the Mere RV32I(M) emulator: its own tiny
   I/O (ecall) and a bump allocator instead of a libc, then a prime sieve over
   dynamically-allocated memory, a recursive quicksort, and a factorial —
   exercising the M extension (mul/div/rem). No libc, no newlib.
   Syscall ABI: a7=64 write(fd,buf,len), a7=93 exit(code). */

static void sys_write(const char *b, int n) {
  register int a0 asm("a0") = 1; register const char *a1 asm("a1") = b;
  register int a2 asm("a2") = n; register int a7 asm("a7") = 64;
  asm volatile ("ecall" : "+r"(a0) : "r"(a1), "r"(a2), "r"(a7) : "memory");
}
static int slen(const char *s) { int n = 0; while (s[n]) n++; return n; }
static void puts_(const char *s) { sys_write(s, slen(s)); }
static void put_uint(unsigned v) {
  char b[12]; int i = 11; b[i--] = 0;
  if (!v) b[i--] = '0';
  while (v) { b[i--] = (char)('0' + v % 10); v /= 10; }   /* div/rem -> RV32M */
  sys_write(&b[i + 1], 11 - i - 1);
}
static void put_int(int v) { if (v < 0) { puts_("-"); v = -v; } put_uint((unsigned)v); }

/* bump allocator over a static arena — a real malloc-style dynamic API */
static char arena[64 * 1024];
static unsigned arena_off = 0;
static void *xalloc(unsigned n) { void *p = &arena[arena_off]; arena_off += (n + 7) & ~7u; return p; }

static void quicksort(int *a, int lo, int hi) {
  if (lo >= hi) return;
  int pivot = a[(lo + hi) / 2], i = lo, j = hi;
  while (i <= j) {
    while (a[i] < pivot) i++;
    while (a[j] > pivot) j--;
    if (i <= j) { int t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
  }
  quicksort(a, lo, j); quicksort(a, i, hi);
}

int main(void) {
  puts_("A bigger C program on the Mere RV32I(M) emulator\n");
  puts_("-------------------------------------------------\n");

  const int N = 10000;
  char *sieve = (char *)xalloc(N + 1);        /* dynamic allocation */
  for (int i = 0; i <= N; i++) sieve[i] = 1;
  sieve[0] = sieve[1] = 0;
  for (int i = 2; i * i <= N; i++)
    if (sieve[i]) for (int j = i * i; j <= N; j += i) sieve[j] = 0;
  int count = 0;
  for (int i = 2; i <= N; i++) count += sieve[i];
  puts_("primes up to "); put_uint(N); puts_(": "); put_uint(count); puts_(" found\n");
  puts_("first 15:");
  int shown = 0;
  for (int i = 2; i <= N && shown < 15; i++) if (sieve[i]) { puts_(" "); put_uint(i); shown++; }
  puts_("\n");

  int data[] = { 37, 4, 91, 12, 55, 8, 73, 21, 66, 1, 44, 99, 30, 17, 82 };
  int n = sizeof(data) / sizeof(data[0]);
  quicksort(data, 0, n - 1);
  puts_("sorted:");
  for (int i = 0; i < n; i++) { puts_(" "); put_int(data[i]); }
  puts_("\n");

  unsigned f = 1;
  for (int i = 1; i <= 12; i++) f *= (unsigned)i;    /* MUL */
  puts_("12! = "); put_uint(f); puts_("\n");
  return 0;
}

__attribute__((section(".text.init"), naked)) void _start(void) {
  asm volatile ("li sp, 0x70000\n call main\n li a7, 93\n ecall\n");
}
