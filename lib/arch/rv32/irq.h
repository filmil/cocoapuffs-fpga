// SPDX-License-Identifier: Apache-2.0

/**
 * @file
 * @brief RISC-V 32-bit interrupt handling.
 */

#ifndef _LIB_ARCH_RV32_IRQ_H
#define _LIB_ARCH_RV32_IRQ_H

#include <cstdint>
#include <cstddef>

namespace lib {

/**
 * @brief Function pointer type for interrupt handlers.
 * @param p A pointer to user data.
 * @param irqs A bitmask of pending interrupts.
 */
typedef void (*irq_handler_t)(void *p, uint32_t irqs);

/**
 * @brief The default interrupt handler.
 */
extern "C" void default_handler() __attribute__ (( interrupt("machine") ));

} // namespace lib

#endif // _LIB_ARCH_RV32_IRQ_H
