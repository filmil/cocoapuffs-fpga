// SPDX-License-Identifier: Apache-2.0

#include <cstdint>
#include <cstddef>
#include <cstdio>
#include <cstring>

#include "lib/ihex/ihex.h"
#include "lib/memtest/memtest.h"
#include "lib/hw/memory_map.h"
#include "lib/pic.h"
#include "lib/timer.h"
#include "lib/uart.h"
#include "lib/uart/uart.h"

#include "kk_ihex.h"
#include "kk_ihex_read.h"

static uint32_t kRamStart = lib::hw::kMemoryBase;
static volatile uint32_t * kMemoryBegin = (uint32_t*)(kRamStart);

extern "C" ihex_bool_t ihex_data_read(struct ihex_state* ihex,
        ihex_record_type_t type,
        ihex_bool_t checksum_error) {
    return lib::ihex::ihex_data_read(ihex, type, checksum_error);
}

static char buf[256];

using lib::TestWithC;
using lib::TestOneCell;

int main(void) {
    kRamStart = lib::hw::kMemoryBase;
    kMemoryBegin = lib::hw::MemStartPtr();
    lib::ihex::line = 1;
    printme("ihex:");

    lib::ihex::gEof = false;
    struct ihex_state ihex;
    ihex_begin_read(&ihex);
    bool first_pass = true;
    while (!lib::ihex::gEof) {
        if (!first_pass) {
            uart_putchar(0x11);
        }
        first_pass = false;
        bool line_ok = uart_getline(buf, sizeof(buf));
        uart_putchar(0x13);
        if (line_ok == false) {
            uart_putchar(0x11); // XON, continue comms.
            printme("1 err");
            for(;;);
        }
        ihex_read_bytes(&ihex, buf, strlen(buf));
    }
    ihex_end_read(&ihex);
    uart_putchar(0x11); // XON, continue comms.

    uint32_t begin = *kMemoryBegin;
    // First bytes of the program.
    kprintf("b: 0x%08x\n", begin);
    // The address of the memory beginning.
    kprintf("m: 0x%08x\n", kMemoryBegin);

    void (*jumpfn)() = (void(*)())kMemoryBegin;
    // Where we will be jumping.
    kprintf("j: 0x%08x\n", jumpfn);
    jumpfn();

    // If we return from jumpfn(), we halt.
    printme("halt.");

    for(;;);

    return 0;
}
