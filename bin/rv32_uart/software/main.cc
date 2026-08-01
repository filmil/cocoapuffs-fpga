// SPDX-License-Identifier: Apache-2.0

#include <stdint.h>
#include <stddef.h>

#include "lib/uart/uart.h"

// Verify.

int main(void) {
    while (1) {
        uart_print("\r\n\r\n======================\r\n");
        uart_print("hello from rv32.\r\n");
        uart_print("======================\r\n");
        pause_for_spins(10000);
    }
    return 0;
}
