#include <stdint.h>
#include <stddef.h>
#include <cstdio>
#include <cstdarg>

#include "lib/uart/uart.h"

int main(void) {
    printme("SERV: Booting. Releasing Muntjac reset and routing UART...\n");
    
    volatile uint32_t *perctl = (volatile uint32_t *)0x40000040;
    *perctl = 0x00000002; // Bit 0 = 0 (de-assert reset), Bit 1 = 1 (switch UART to muntjac)
    
    for (;;) {
        // Loop forever
    }
    return 0;
}
