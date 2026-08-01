// SPDX-License-Identifier: Apache-2.0
#ifndef PERINPUT_BITS_H
#define PERINPUT_BITS_H

#include <cstdint>

namespace perinput {

// Base address for the perinput peripheral on the muntjac board.
constexpr uint32_t BASE_ADDRESS = 0x40000050;

// Total bits mapped:
//   mem_a_o (143 bits) -> bits [142:0]
//   mem_a_valid (1 bit) -> bit [143]
//   mem_c_o (135 bits) -> bits [278:144]
//   mem_e_o (1 bit) -> bit [279]
//   padding (1 bit) -> bit [280]

// Offsets in 32-bit registers (address offsets from base)
constexpr uint32_t REG_0_OFFSET = 0x00; // bits 31..0    (mem_a_o[31:0])
constexpr uint32_t REG_1_OFFSET = 0x04; // bits 63..32   (mem_a_o[63:32])
constexpr uint32_t REG_2_OFFSET = 0x08; // bits 95..64   (mem_a_o[95:64])
constexpr uint32_t REG_3_OFFSET = 0x0C; // bits 127..96  (mem_a_o[127:96])
constexpr uint32_t REG_4_OFFSET = 0x10; // bits 159..128 (mem_a_o[142:128], mem_a_valid, mem_c_o[15:0])
constexpr uint32_t REG_5_OFFSET = 0x14; // bits 191..160 (mem_c_o[47:16])
constexpr uint32_t REG_6_OFFSET = 0x18; // bits 223..192 (mem_c_o[79:48])
constexpr uint32_t REG_7_OFFSET = 0x1C; // bits 255..224 (mem_c_o[111:80])
constexpr uint32_t REG_8_OFFSET = 0x20; // bits 287..256 (mem_c_o[134:112], mem_e_o, padding)

// Masks and Shifts for specific fields
// ------------------------------------

// mem_a_valid: bit 143 (which is bit 15 of REG_4)
constexpr uint32_t MEM_A_VALID_REG_OFFSET = REG_4_OFFSET;
constexpr uint32_t MEM_A_VALID_MASK       = (1UL << 15);
constexpr uint32_t MEM_A_VALID_SHIFT      = 15;

// mem_e_o: bit 279 (which is bit 23 of REG_8)
constexpr uint32_t MEM_E_O_REG_OFFSET     = REG_8_OFFSET;
constexpr uint32_t MEM_E_O_MASK           = (1UL << 23);
constexpr uint32_t MEM_E_O_SHIFT          = 23;

// Helper functions to read from memory-mapped peripheral
inline uint32_t read_reg(uint32_t offset) {
    return *(volatile uint32_t*)(BASE_ADDRESS + offset);
}

inline uint8_t read_mem_a_valid() {
    return (read_reg(MEM_A_VALID_REG_OFFSET) & MEM_A_VALID_MASK) >> MEM_A_VALID_SHIFT;
}

inline uint8_t read_mem_e_o() {
    return (read_reg(MEM_E_O_REG_OFFSET) & MEM_E_O_MASK) >> MEM_E_O_SHIFT;
}

} // namespace perinput

#endif // PERINPUT_BITS_H
