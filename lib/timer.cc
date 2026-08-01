// SPDX-License-Identifier: Apache-2.0

#include "lib/timer.h"
#include "lib/pic.h"

namespace lib {

Timer::Timer(uint32_t base_address, uint32_t default_counter)
    : irq_(base_address + timer::kIrqReg),
    counter_(base_address + timer::kCounterReg),
    default_counter_(default_counter) {
    // Initially program the counter for maximum wait, and clear the interrupt.
    counter_.Write(static_cast<uint32_t>(default_counter));
    ClearIrq();
}

int Timer::ClearIrq() {
    return irq_.Write(0);
}

int Timer::ReadIrq(uint32_t* value) {
    return irq_.Read(value);
}

int Timer::ReadCounter(uint32_t* value) {
    return counter_.Read(value);
}

int Timer::WriteCounter(uint32_t value) {
    return counter_.Write(value);
}

void Timer::InterruptHandler(Pic* p, uint32_t irq) {
    WriteCounter(default_counter_);
    ClearIrq();
}

} // namespace lib
