// SPDX-License-Identifier: Apache-2.0

/**
 * @file
 * @brief A programmable interrupt controller (PIC).
 */

#ifndef _LIB_PIC_H
#define _LIB_PIC_H

#include <cstdint>
#include <cstddef>

#include "lib/arch/irq.h"
#include "lib/reg.h"
#include "lib/timer.h"
#include "lib/uart.h"

namespace lib {

namespace pic {
  const uint32_t kBaseAddress = 0x40000030;

  constexpr uint32_t kTimerIrqBit = (1 << 0);
  constexpr uint32_t kUartIrqBit = (1 << 1);

} // namespace pic

/**
 * @brief This struct holds the state of the PIC.
 */
class Pic {
  public:
    /**
     * @brief Initializes the PIC.
     * @param base_address The base address of the PIC's memory-mapped registers.
     * @param handler The interrupt handler to be called when an interrupt occurs.
     */
    explicit Pic(size_t base_address);

    void SetTimerHandler(Timer* timer);
    void SetUartHandler(Uart* uart);

    /**
     * @brief Clears pending interrupts.
     * @param mask A bitmask of the interrupts to clear.
     * @return 0 on success, -1 on error.
     */
    int ClearIrq(uint32_t mask);
    /**
     * @brief Sets the interrupt mask.
     * @param mask The new interrupt mask.
     * @return 0 on success, -1 on error.
     */
    int SetMask(uint32_t mask);

    /**
     * @brief Reads the interrupt mask.
     * @param mask A pointer to a uint32_t to store the interrupt mask.
     * @return 0 on success, -1 on error.
     */
    int ReadMask(uint32_t* mask);

    void EnableInterrupts();
    void DisableInterrupts();
    void WaitForInterrupt();

  private:
    friend uint32_t read_irqs();
    friend void default_handler();

    void InterruptHandler();

    /** The current interrupt mask. */
    volatile uint32_t mask_;
    Timer* timer_handler_;
    Uart* uart_handler_;

    Reg mask_reg_;
    Reg irq_reg_;
};

} // namespace lib

#endif // _LIB_PIC_H

