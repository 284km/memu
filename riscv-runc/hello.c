/* A freestanding C program compiled to RISC-V RV32I and run on the Mere
   emulator. Syscall ABI (ecall): a7=64 write(fd,buf,len), a7=93 exit(code). */

static void sys_write(const char *buf, int len) {
  register int a0 asm("a0") = 1;            /* fd = stdout */
  register const char *a1 asm("a1") = buf;
  register int a2 asm("a2") = len;
  register int a7 asm("a7") = 64;
  asm volatile ("ecall" : "+r"(a0) : "r"(a1), "r"(a2), "r"(a7) : "memory");
}
static void sys_exit(int code) {
  register int a0 asm("a0") = code;
  register int a7 asm("a7") = 93;
  asm volatile ("ecall" : : "r"(a0), "r"(a7) : "memory");
  __builtin_unreachable();
}

static int slen(const char *s) { int n = 0; while (s[n]) n++; return n; }
static void print(const char *s) { sys_write(s, slen(s)); }
static void print_uint(unsigned int v) {
  char buf[12]; int i = 11; buf[i--] = '\n';
  if (v == 0) buf[i--] = '0';
  while (v) { buf[i--] = (char)('0' + (v % 10)); v /= 10; }   /* uses libgcc soft div */
  sys_write(&buf[i + 1], 11 - i);
}

int main(void) {
  print("Hello from C, compiled to RISC-V RV32I, running on a Mere emulator!\n");
  unsigned int sum = 0;
  for (unsigned int i = 1; i <= 100; i++) sum += i;
  print("sum 1..100 = "); print_uint(sum);           /* 5050 */
  unsigned int a = 0, b = 1;
  for (int i = 0; i < 20; i++) { unsigned int t = a + b; a = b; b = t; }
  print("fib(20)    = "); print_uint(a);              /* 6765 */
  return 0;
}

/* entry point placed at address 0 by the linker script. Pure asm (naked):
   set the stack, call main, then exit via the syscall. */
__attribute__((section(".text.init"), naked)) void _start(void) {
  asm volatile (
    "li sp, 0xF000\n"
    "call main\n"
    "li a7, 93\n"      /* SYS_exit; a0 holds main's return value */
    "ecall\n"
  );
}
