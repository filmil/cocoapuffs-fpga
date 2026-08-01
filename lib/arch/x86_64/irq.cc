// SPDX-License-Identifier: Apache-2.0

#include "lib/arch/x86_64/irq.h"

#include <cstdint>

namespace lib {

    extern irq_handler_t main_handler;
    extern uint32_t read_irqs();

    void default_handler() {
        if (main_handler == nullptr) {
            return;
        }
        main_handler(nullptr, read_irqs());
    }

} // namespace lib
