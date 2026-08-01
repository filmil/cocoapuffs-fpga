// SPDX-License-Identifier: Apache-2.0

/**
 * @file
 * @brief x86-64 interrupt handling.
 */

#ifndef _LIB_ARCH_X86_64_IRQ_H
#define _LIB_ARCH_X86_64_IRQ_H

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
void default_handler(void*) __attribute(( interrupt ));

} // namespace lib

#endif // _LIB_ARCH_X86_64_IRQ_H
