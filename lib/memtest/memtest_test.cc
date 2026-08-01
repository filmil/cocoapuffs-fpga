// SPDX-License-Identifier: Apache-2.0

#include "lib/memtest/memtest.h"
#include <iostream>
#include <vector>
#include <cassert>

namespace lib {

// To test failure, we need a "faulty" memory.
struct FaultyMemory {
    std::vector<uint32_t> data;
    size_t fault_index;
    bool fault_active;

    FaultyMemory(size_t size) : data(size, 0), fault_index(0), fault_active(false) {}

    void set_fault(size_t index) {
        fault_index = index;
        fault_active = true;
    }

    // This is tricky because Memtest::Test uses a raw pointer.
    // In a real environment, we'd need to use something like mmap or a custom pointer type if Memtest was templated.
    // Given the current Memtest, we can only test it with real memory.
};

void TestMemtestSuccess() {
    std::cout << "Running TestMemtestSuccess..." << std::endl;
    const uint32_t cell_count = 10;
    const uint32_t base_pattern = 0xDEADBEEF;
    std::vector<uint32_t> memory(cell_count, 0);
    uintptr_t base_address = reinterpret_cast<uintptr_t>(memory.data());

    Memtest memtest(base_address, base_pattern, cell_count);
    Result res = memtest.Test();

    if (!res.ok) {
        std::cerr << "TestMemtestSuccess failed: expected ok, but got error at addr "
                  << std::hex << res.addr << std::endl;
        exit(1);
    }
    for (uint32_t i = 0; i < cell_count; ++i) {
        if (memory[i] != base_pattern) {
             std::cerr << "TestMemtestSuccess failed: memory at index " << i
                       << " not set to pattern. Expected " << std::hex << base_pattern
                       << " but got " << memory[i] << std::endl;
             exit(1);
        }
    }
    std::cout << "TestMemtestSuccess passed." << std::endl;
}

void TestMemtestEmpty() {
    std::cout << "Running TestMemtestEmpty..." << std::endl;
    const uint32_t cell_count = 0;
    const uint32_t base_pattern = 0xDEADBEEF;
    uintptr_t base_address = 0; // Should not be accessed

    Memtest memtest(base_address, base_pattern, cell_count);
    Result res = memtest.Test();

    if (!res.ok) {
        std::cerr << "TestMemtestEmpty failed: expected ok for 0 cells." << std::endl;
        exit(1);
    }
    std::cout << "TestMemtestEmpty passed." << std::endl;
}

} // namespace lib

int main() {
    lib::TestMemtestSuccess();
    lib::TestMemtestEmpty();
    std::cout << "All tests passed!" << std::endl;
    return 0;
}
