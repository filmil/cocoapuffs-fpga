// SPDX-License-Identifier: Apache-2.0

extern int main();
extern void __libc_init_array(void);
extern void __libc_fini_array(void);

/* Heap management */
extern char _end; /* Defined by the linker script */
static char *heap_end = 0;

void * _sbrk(int incr)
{
    char *prev_heap_end;

    if (heap_end == 0) {
        heap_end = &_end;
    }

    prev_heap_end = heap_end;
    heap_end += incr;

    return (void *)prev_heap_end;
}

/* System call stubs */

int _close(int file) {
    return -1;
}

int _fstat(int file, void *st) {
    return 0;
}

int _isatty(int file) {
    return 1;
}

int _lseek(int file, int ptr, int dir) {
    return 0;
}

int _read(int file, char *ptr, int len) {
    return 0;
}

/* Dummy write: can be hooked to UART later if needed. */
extern void uart_putchar(char c);
int _write(int file, char *ptr, int len) {
    for (int i = 0; i < len; i++) {
        uart_putchar(ptr[i]);
    }
    return len;
}

void _exit(int status) {
    for(;;);
}

void _start(void)
{
    /* Initialize global constructors and other C++ initializers. */
    __libc_init_array();

    /* Call the program entry point. */
    main();

    /* Clean up global destructors (if needed, though rare in bare metal). */
    __libc_fini_array();

    /* Hang if main returns. */
    for(;;);
}
