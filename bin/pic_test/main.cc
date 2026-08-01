#include <stdint.h>
#include <stddef.h>
//#include <cstdio>
//#include <cstdarg>

#include "lib/uart/uart.h"
#include "lib/pic.h"
#include "lib/uart.h"

char buf[256];

int main(void) {
    lib::Pic pic(lib::pic::kBaseAddress);
    lib::Uart uart(lib::uart::kBaseAddress);
    lib::Timer timer(lib::timer::kDefaultBaseAddress, 100000);
    timer.WriteCounter(100000);

    pic.SetUartHandler(&uart);
    pic.SetTimerHandler(&timer);

    pic.SetMask(lib::pic::kTimerIrqBit);
    pic.EnableInterrupts();

    uint32_t counter = 0;

    bool once = false;
    for(;;) {
        uint32_t counter_val = 0;
        if (timer.ReadCounter(&counter_val) != 0) {
            if (!once) {
                kprintf("Error reading timer counter\r\n");
            }
            once = true;
        };
        kprintf("timer: %u\r\n", counter_val);
    }
}
