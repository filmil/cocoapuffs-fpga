// SPDX-License-Identifier: Apache-2.0

#include <cstdint>
#include <cstddef>
#include <cstdio>
#include <cstring>

#include "lib/memtest/memtest.h"
#include "lib/pic.h"
#include "lib/timer.h"
#include "lib/uart.h"
#include "lib/uart/uart.h"

#include "kk_ihex.h"
#include "kk_ihex_read.h"

bool gEof = false;

static uint32_t kRamStart = 0x80000000;
static volatile uint32_t * kMemoryBegin = (uint32_t*)(kRamStart);

extern "C" ihex_bool_t ihex_data_read(struct ihex_state* ihex,
        ihex_record_type_t type,
        ihex_bool_t checksum_error) {
    if (checksum_error) {
        printme("ihex err");
        for(;;);
    }
    if (type == IHEX_DATA_RECORD) {
        char* address = (char*) IHEX_LINEAR_ADDRESS(ihex) + kRamStart;
        size_t length = ihex->length;
        size_t line_length = ihex->line_length;
        kprintf("a: %08x: len=%4d(%4x): line_len=%4d(%4x)",
            ihex->address, length, length, line_length, line_length);
        for(size_t i = 0; i < ihex->length; i++) {
            address[i] = ihex->data[i];
            //kprintf("%0x ", ihex->data[i]);
        }
        kprintf("\n");
    } else if (type == IHEX_END_OF_FILE_RECORD) {
        printme("EOF");
        gEof = true;
    }
    return true;
}

static char buf[256];

using lib::TestWithC;
using lib::TestOneCell;

int main(void) {
    kRamStart = 0x80000000;
    kMemoryBegin = (uint32_t*)kRamStart;

    TestOneCell(0x11111111, 0);
    printme(">-< memtest");

    printme("ihex:");

    gEof = false;
    struct ihex_state ihex;
    printmef("buf: %d", sizeof(buf));
    ihex_begin_read(&ihex);
    while (!gEof) {
        if (uart_getline(buf, sizeof(buf)) == false) {
            printme("1 err");
            for(;;);
        }
        //kprintf("%s\n", buf);
        ihex_read_bytes(&ihex, buf, strlen(buf));
    }
    ihex_end_read(&ihex);

    printme("u");

    uint32_t begin = *kMemoryBegin;
    printme("t");
    kprintf("b: 0x%08x\n", begin);
    kprintf("m: %0x\n", kMemoryBegin);

    void (*jumpfn)() = (void(*)())0x80000004;
    kprintf("m: %0x\n", jumpfn);
    jumpfn();

    printme("completed");

    for(;;);

    return 0;
}
