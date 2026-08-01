// SPDX-License-Identifier: Apache-2.0

#include "lib/memtest/memtest.h"
#include "lib/uart/uart.h"

#include <cstdint>
#include <cstddef>

namespace lib {

Memtest::Memtest(uintptr_t base_address, uint32_t base_pattern, uint32_t cell_count) :
    base_address_(base_address), base_pattern_(base_pattern),
        cell_count_(cell_count) {}

Result Memtest::Test() {
    Result ret;
    volatile uint32_t* base = (uint32_t*)(base_address_);
    if (cell_count_ == 0) {
        ret.ok = true;
        return ret;
    }
    *base = base_pattern_;
    // Go write.
    for (uint32_t i = 0; i < cell_count_; i++) {
        *(base + i) = base_pattern_;
    }
    // Go read and compare.
    for (uint32_t i = 0; i < cell_count_; i++) {
        uint32_t v = *(base+i);
        uint32_t e = base_pattern_;
        if (v != e) {
            ret.ok = false;
            ret.expected = e;
            ret.actual = v;
            ret.addr = reinterpret_cast<uintptr_t>(base + i);
            return ret;
        }
    }
    ret.ok = true;
    return ret;
}

static const uint32_t kRamStart = 0x80000000;
static volatile uint32_t * kMemoryBegin = (uint32_t*)(kRamStart);


bool TestOneCell(uint32_t expected, size_t cell) {
    kMemoryBegin[cell] = expected;
    volatile uint32_t actual = kMemoryBegin[cell];
    if (actual != expected) {
        printmef("mem: 0x08%x: expect: 0x%08x, actual: 0x%08x",
            kRamStart + sizeof(uint32_t)*cell, expected, actual);
        return false;
    }
    return true;
}

bool TestWithC(uint32_t value, size_t limit) {
    bool ret = true;
    for (size_t i = 0; i < limit; i++) {
        if (TestOneCell(value, i)) {
            ret = false;
        }
    }
    return ret;
}


} // namespace lib
