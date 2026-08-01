// SPDX-License-Identifier: Apache-2.0

#include "lib/reg.h"

#include <cstdint>
#include <cstddef>

#ifndef __riscv
#include <map>
#endif

namespace lib {
namespace {

#ifndef __riscv
std::map<uint32_t, uint32_t> mock_regs;
#endif

int lib_reg_read(uint32_t address, uint32_t* value) {
#ifdef __riscv
    *value = 0;
    volatile const uint32_t* reg = (uint32_t*)(address);
    *value = *reg;
#else
    *value = mock_regs[address];
#endif
    return 0;
}

int lib_reg_write(uint32_t address, uint32_t value) {
#ifdef __riscv
    volatile uint32_t* reg = (uint32_t*)(address);
    *reg = value;
#else
    mock_regs[address] = value;
#endif
    return 0;
}
} // namespace

int Reg::Read(uint32_t* value) {
    return lib_reg_read(this->address_, value);
}

int Reg::Write(uint32_t value) {
    return lib_reg_write(this->address_, value);
}

void Reg::SetMockValue(uint32_t address, uint32_t value) {
#ifndef __riscv
    mock_regs[address] = value;
#endif
}

uint32_t Reg::GetMockValue(uint32_t address) {
#ifndef __riscv
    return mock_regs[address];
#else
    return 0;
#endif
}

void Reg::ClearMockValues() {
#ifndef __riscv
    mock_regs.clear();
#endif
}

} // namespace lib
