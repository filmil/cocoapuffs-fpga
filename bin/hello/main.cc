#include <stdint.h>
#include <stddef.h>
#include <cstdio>
#include <cstdarg>

#include "lib/uart/uart.h"

int main(void) {
    printme("Hello world!");

    printme("halt.");
    for(;;);
    return 0;
}
