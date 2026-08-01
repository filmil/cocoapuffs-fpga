#include <stdint.h>
#include <stddef.h>
#include <cstdio>
#include <cstdarg>

#include "lib/uart/uart.h"
#include "lib/memtest/memtest.h"

using lib::TestWithC;
using lib::TestOneCell;

int main(void) {
    printme("\r\n\r\n\r\n\r\n\r\n\r\n<->");

    TestWithC(0xaaaaaaaa, 6000);
    TestOneCell(0x11111111, 0);
    TestOneCell(0x11111111, 1);
    TestOneCell(0x11111111, 2);
    TestOneCell(0x11111111, 3);
    TestOneCell(0x11111111, 4);
    TestOneCell(0x11111111, 5);
    TestOneCell(0x11111111, 6);
    TestOneCell(0x11111111, 7);
    TestOneCell(0x11111111, 8);
    TestOneCell(0x11111111, 48);
    TestOneCell(0x11111111, 49);
    TestOneCell(0x11111111, 50);
    TestWithC(0xbbbbbbbb, 6000);
    TestOneCell(0x22222222, 50);
    TestOneCell(0x11111111, 48);
    TestOneCell(0x11111111, 49);
    TestOneCell(0x11111111, 50);
    TestOneCell(0x11111111, 51);
    TestOneCell(0x11111111, 52);
    TestOneCell(0x11111111, 53);

    printme(">-<");
    printme("ihex:");
    for(;;);
    return 0;
}
