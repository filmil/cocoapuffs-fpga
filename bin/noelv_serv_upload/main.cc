// SPDX-License-Identifier: Apache-2.0
//
// SERV-side Intel HEX uploader with NOEL-V handoff.
//
// The (bit-serial) SERV core owns the shared UART at reset (percontrol UART mux
// bit = 0). This program receives an Intel HEX stream over that UART and writes
// the decoded bytes to shared RAM at the *absolute* addresses carried in the
// records (so the payload lands at its linked address). When the stream ends it
// hands off: it switches the UART mux to NOEL-V and releases NOEL-V from reset,
// so NOEL-V boots and runs the freshly-uploaded program from shared RAM.
//
// This mirrors //bin/rv32_ddr3exec/software (which jumps to the upload and runs
// it on the rv32 core itself); the only difference is the final step -- enable
// NOEL-V instead of jumping.

#include <cstddef>
#include <cstdint>
#include <cstring>

#include "lib/ihex/ihex.h"
#include "lib/uart.h"
#include "lib/uart/uart.h"

#include "kk_ihex.h"
#include "kk_ihex_read.h"

// percontrol @ 0x40000040: bit0 = UART mux (1 = NOEL-V), bit1 = NOEL-V run,
// bit2 = AHB-recorder dump trigger (rising edge).
static constexpr uintptr_t kPerctl = 0x40000040;
static constexpr uint32_t kMuxToNoelv = 0x1;
static constexpr uint32_t kNoelvRun = 0x2;
static constexpr uint32_t kRecDump = 0x4;

// SERV wb_uart status (read) @ 0x40000010: bit10 (0x400) = TX FIFO empty.
static constexpr uintptr_t kServUart = 0x40000010;
static constexpr uint32_t kTxFifoEmpty = 0x400;

extern "C" ihex_bool_t ihex_data_read(struct ihex_state* ihex,
        ihex_record_type_t type,
        ihex_bool_t checksum_error) {
    return lib::ihex::ihex_data_read(ihex, type, checksum_error);
}

static char buf[256];

int main(void) {
    lib::ihex::line = 1;
    // Announce the SERV (32-bit) boot stage, then prompt for the ihex upload.
    printme("32-bit boot\r\n");
    printme("ihex:");

    // Receive the Intel HEX stream and decode it straight into shared RAM.
    // XON (0x11) / XOFF (0x13) throttle the host between lines because SERV is
    // bit-serial and slow.
    lib::ihex::gEof = false;
    struct ihex_state ihex;
    ihex_begin_read(&ihex);
    bool first_pass = true;
    while (!lib::ihex::gEof) {
        if (!first_pass) {
            uart_putchar(0x11); // XON, request next line.
        }
        first_pass = false;
        bool line_ok = uart_getline(buf, sizeof(buf));
        uart_putchar(0x13); // XOFF while we process the line.
        if (line_ok == false) {
            uart_putchar(0x11); // XON, continue comms.
            printme("1 err");
            for (;;);
        }
        ihex_read_bytes(&ihex, buf, strlen(buf));
    }
    ihex_end_read(&ihex);
    uart_putchar(0x11); // XON, continue comms.

    // Last message while SERV still owns the UART.
    printme("noelv");

    // Drain the SERV wb_uart so "noelv" is fully on the wire before the mux
    // switches -- otherwise the handoff truncates the tail and garbles the seam
    // (issue #145). UartBuf::Put only blocks until a byte is in the 8-deep FIFO,
    // so wait for TX-FIFO-empty, then let the final byte clear the shift reg.
    auto* serv_uart = reinterpret_cast<volatile uint32_t*>(kServUart);
    while ((*serv_uart & kTxFifoEmpty) == 0u) { /* wait for TX FIFO empty */ }
    for (volatile uint32_t i = 0; i < 4000u; ++i) { /* shift-register drain */ }

    // Hand off to NOEL-V: switch the UART mux to NOEL-V and release NOEL-V from
    // reset. After this write, SERV no longer drives the shared UART -- NOEL-V
    // does -- and NOEL-V runs the uploaded program from shared RAM.
    *reinterpret_cast<volatile uint32_t*>(kPerctl) = kMuxToNoelv | kNoelvRun;

    // Auto-trigger the AHB recorder ~30 s after enabling NOEL-V, so the captured
    // trace dumps over the (recorder-stolen) UART without a key1 press -- this is
    // what lets the capture run while nobody is at the board. The iteration count
    // is approximate (bit-serial SERV); 30 s is only a floor on how long NOEL-V
    // runs before we snapshot the trace.
    for (volatile uint32_t i = 0; i < 65000000u; ++i) { /* ~30 s on SERV */ }
    *reinterpret_cast<volatile uint32_t*>(kPerctl) =
        kMuxToNoelv | kNoelvRun | kRecDump;

    for (;;);
    return 0;
}
