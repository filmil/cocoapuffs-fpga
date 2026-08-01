// SPDX-License-Identifier: Apache-2.0

/**
 * @file
 * @brief A countdown timer.
 */

#ifndef _LIB_TIMER_H
#define _LIB_TIMER_H

#include "lib/reg.h"

#include <cstdint>
#include <cstddef>

namespace lib {

namespace timer {
    const uint32_t kDefaultBaseAddress = 0x40000020;
    const uint32_t kIrqReg = 0x0;
    const uint32_t kCounterReg = 0x4;
}

class Pic;

/**
 * @brief A countdown timer.
 */
class Timer {
  public:
    /**
     * @brief Constructs a new Timer object.
     * @param base_address The base address of the timer's memory-mapped registers.
     */
    Timer(uint32_t base_address, uint32_t default_counter = 0xffffffff);

    /**
     * @brief Reads the interrupt status.
     * @param value A pointer to a uint32_t to store the interrupt status.
     * @return 0 on success, -1 on error.
     */
    int ReadIrq(uint32_t *value);
    /**
     * @brief Clears the interrupt.
     * @return 0 on success, -1 on error.
     */
    int ClearIrq();
    /**
     * @brief Reads the counter value.
     * @param value A pointer to a uint32_t to store the counter value.
     * @return 0 on success, -1 on error.
     */
    int ReadCounter(uint32_t* value);
    /**
     * @brief Writes the counter value.
     * @param value The value to write to the counter.
     * @return 0 on success, -1 on error.
     */
    int WriteCounter(uint32_t value);

    void InterruptHandler(Pic* p, uint32_t irq);

  private:
    Reg irq_;
    Reg counter_;
    uint32_t default_counter_;

};

} // namespace lib

#endif // _LIB_TIMER_H
