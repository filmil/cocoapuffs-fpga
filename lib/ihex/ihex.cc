// SPDX-License-Identifier: Apache-2.0

#include "lib/ihex/ihex.h"
#include "lib/hw/memory_map.h"
#include "lib/uart/uart.h"

namespace lib::ihex {

bool gEof = false;
int line = 1;
static int dot_count = 0;

ihex_bool_t ihex_data_read(struct ihex_state* ihex,
        ihex_record_type_t type,
        ihex_bool_t checksum_error) {
    if (type == IHEX_DATA_RECORD) {
        // This will be whatever address is given in the file.
        char* address = (char*) IHEX_LINEAR_ADDRESS(ihex);
        if (dot_count == 0) {
            kprintf("%08x: ", address);
        }
        for(size_t i = 0; i < ihex->length; i++) {
            address[i] = ihex->data[i];
        }
        kprintf(".");
        dot_count++;
        if (dot_count >= 40) {
            kprintf("\n");
            dot_count = 0;
        }
    } else if (type == IHEX_END_OF_FILE_RECORD) {
        if (dot_count != 0) {
            kprintf("\n");
            dot_count = 0;
        }
        printme("EOF");
        gEof = true;
    }
    if (checksum_error) {
        printmef("ihex err: line %d type: %d\n", line, type);
        for(;;);
    }
    line++;
    return true;
}

} // namespace lib::ihex
