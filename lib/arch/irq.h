// SPDX-License-Identifier: Apache-2.0

/**
 * @file
 * @brief Architecture-specific interrupt handling.
 */

#ifndef _LIB_ARCH_IRQ_H
#define _LIB_ARCH_IRQ_H

#ifdef PLATFORM_X86_64
#include "lib/arch/x86_64/irq.h"
#endif

#ifdef PLATFORM_RV32
#include "lib/arch/rv32/irq.h"
#endif

#endif // _LIB_ARCH_IRQ_H
