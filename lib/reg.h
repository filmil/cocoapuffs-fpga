// SPDX-License-Identifier: Apache-2.0

/**
 * @file
 * @brief Memory-mapped register access.
 */

#ifndef _LIB_REG_H
#define _LIB_REG_H

#include <cstdint>
#include <cstddef>

namespace lib {

/**
 * @brief A memory-mapped register.
 */
class Reg {
    public:
        /**
         * @brief Constructs a new Reg object.
         * @param address The address of the register.
         */
        Reg(uint32_t address) : address_(address) {}
        /**
         * @brief Reads a 32-bit value from the register.
         * @param value A pointer to a uint32_t to store the value read.
         * @return 0 on success, -1 on error.
         */
        int Read(uint32_t* value);
        /**
         * @brief Writes a 32-bit value to the register.
         * @param value The value to write.
         * @return 0 on success, -1 on error.
         */
        int Write(uint32_t value);

        static void SetMockValue(uint32_t address, uint32_t value);
        static uint32_t GetMockValue(uint32_t address);
        static void ClearMockValues();

    private:
        uint32_t address_;
};

} // namespace lib

/**
 * @brief Reads a 32-bit value from a memory-mapped register.
 * @param address The address of the register to read.
 * @param value A pointer to a uint32_t to store the value read.
 * @return 0 on success, -1 on error.
 */
int lib_reg_read(uint32_t address, uint32_t* value);

/**
 * @brief Writes a 32-bit value to a memory-mapped register.
 * @param address The address of the register to write to.
 * @param value The value to write.
 * @return 0 on success, -1 on error.
 */
int lib_reg_write(uint32_t address, uint32_t value);

#endif //_LIB_REG_H
