// SPDX-License-Identifier: Apache-2.0

#include <stdint.h>
#include <stddef.h>

#include <cstdarg>
#include <cstdio>

#include "lib/uart/uart.h"

#ifndef UART_ADDRESS
#error You must define UART_ADDRESS.
#endif
static volatile uint32_t *uart = (uint32_t*)(UART_ADDRESS); // Extern.

bool uart_is_empty(uint32_t c) {
    return (c & EMPTY_BITMASK) != 0;
}

bool uart_is_full(uint32_t c) {
    return (c & FULL_BITMASK) != 0;
}


static uint32_t uart_raw_read() {
    volatile int32_t v = *uart;
    return v;
}

static void uart_raw_write(volatile uint32_t v) {
    *uart = v;
}

// Polling UART.
class UartBuf {
public:
    UartBuf() {};

    bool GetAsync(char *c);
    bool PutAsync(char c);

    bool Get(char *c);
    bool Put(char c);

    // Test if UART can accept a write, but does not send anything.
    bool CanWrite();

private:
    char buf_[256];
    size_t rd_ = 0;
    size_t wr_ = 0;
};

bool UartBuf::CanWrite() {
    // Test if we can actually write. If not, we have to save any read bytes
    // into a buffer.
    uint32_t v = uart_raw_read();
    if (!uart_is_empty(v)) {
        // We read something, save it into the buffer.
        char r = v & 0xff;
        buf_[wr_] = r;
        wr_ = (wr_ + 1) % sizeof(buf_);
    }
    return !uart_is_full(v);
}

bool UartBuf::GetAsync(char *c) {
    if (rd_ != wr_) {
        *c = buf_[rd_];
        rd_ = (rd_ + 1) % sizeof(buf_);
        return true;
    }

    // Else, it's an empty UART.
    volatile uint32_t v = uart_raw_read();
    if (uart_is_empty(v)) {
        return false;
    }
    // UART had something.
    *c = v & 0xff;
    return true;
}

bool UartBuf::PutAsync(char c) {
    if (!CanWrite()) {
        return false;
    }
    uint32_t w = static_cast<uint32_t>(c);
    uart_raw_write(w);
    return true;
}

bool UartBuf::Put(char c) {
    bool ret = false;
    do {
        ret = PutAsync(c);
    } while (!ret);
    return ret;
}

bool UartBuf::Get(char *c) {
    while (!GetAsync(c));
    return true;
}

static UartBuf uart_buf{};


volatile void uart_getchar(char* c) {
    uart_buf.Get(c);
}

void uart_putchar(char c) {
    uart_buf.Put(c);
}

void pause_for_spins(uint32_t pause) {
    for (; pause > 0; pause--);
}

alignas(4) static char buf[256];

void printme(const char* p) {
    uart_print(p);
    uart_print("\r\n");
}

int printmef(const char *format, ...) {
    va_list args;
    va_start(args, format);
    int ret = vsnprintf(buf, sizeof(buf), format, args);
    va_end(args);
    if (ret < 0) {
        buf[0] = '\0';
    } else if ((size_t)ret >= sizeof(buf)) {
        buf[sizeof(buf) - 1] = '\0';
    }
    printme(buf);
    return ret;
}

int kprintf(const char *format, ...) {
    va_list args;
    va_start(args, format);
    int ret = vsnprintf(buf, sizeof(buf), format, args);
    va_end(args);
    if (ret < 0) {
        buf[0] = '\0';
    } else if ((size_t)ret >= sizeof(buf)) {
        buf[sizeof(buf) - 1] = '\0';
    }
    uart_print(buf);
    return ret;
}

bool uart_getline(char *buf, size_t read_chars) {
    if (read_chars == 0) {
        return false;
    }
    while (read_chars > 0) {
        char c{};
        uart_getchar(&c);
        *buf++ = c;
        read_chars--;
        if (c == '\n') {
            break;
        }
    }
    if (read_chars == 0) {
        --buf;
        *buf = '\0';
        return false;
    }
    *buf = '\0';
    return true;
}

void uart_wait_available() {
    while (!uart_buf.CanWrite());
}

int uart_print(const char *str) {
    while (*str != '\0')
    {
        uart_putchar(*str);
        str++;
    }
    return 0;
}

