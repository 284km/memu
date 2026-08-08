/* A deterministic compute benchmark for the Mere RV32I emulator: a xorshift32
   PRNG run many times, accumulating a checksum (so nothing is optimized away).
   Pure ALU (shift/xor/add) — a clean throughput test. */
static void sys_write(const char *b, int n) {
  register int a0 asm("a0") = 1; register const char *a1 asm("a1") = b;
  register int a2 asm("a2") = n; register int a7 asm("a7") = 64;
  asm volatile ("ecall" : "+r"(a0) : "r"(a1), "r"(a2), "r"(a7) : "memory");
}
static int slen(const char *s){int n=0;while(s[n])n++;return n;}
static void puts_(const char *s){ sys_write(s, slen(s)); }
static void put_uint(unsigned v){ char b[12]; int i=11; b[i--]=0;
  if(!v)b[i--]='0'; while(v){b[i--]=(char)('0'+v%10);v/=10;} sys_write(&b[i+1],11-i-1); }

int main(void){
  unsigned x = 2463534242u, sum = 0;
  for (unsigned i = 0; i < 3000000u; i++) {
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    sum += x;
  }
  puts_("xorshift32 x3,000,000 checksum = "); put_uint(sum); puts_("\n");
  return 0;
}
__attribute__((section(".text.init"), naked)) void _start(void){
  asm volatile ("li sp, 0xF000\n call main\n li a7, 93\n ecall\n");
}
