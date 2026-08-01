// SPDX-License-Identifier: Apache-2.0

#include "lib/pic.h"

#include <cstdint>
#include <cstddef>

#include "lib/reg.h"
#include "lib/arch/irq.h"
#include "lib/uart/uart.h"
#include "pic.h"

namespace lib {
namespace {

static const size_t MASK_REG = 0;
static const size_t IRQ_REG = 4;

// This seems to be a Serv thing. It's not documented.
static const int kExternalTimerIrq = 7;

void set_interrupt_handler(void (*handler)()) {
    asm(
        "csrw mtvec, %0\n\t"
        "csrrsi x0, mstatus, 8\n\t"
        : // outputs
        : "r"(handler)
        : // clobbered
    );
}

uint32_t get_mcause(void) {
    unsigned long cause;
    __asm__ __volatile__("csrr %0, mcause" : "=r"(cause));
    return cause;
}

inline void enable_interrupt(unsigned int irq) {
	uint32_t mie;
	__asm__ volatile ("csrrs %0, mie, %1\n"
			  : "=r" (mie)
			  : "r" (1 << irq));
}

inline void disable_interrupt(unsigned int irq) {
	uint32_t mie;
	__asm__ volatile ("csrrc %0, mie, %1\n"
			  : "=r" (mie)
			  : "r" (1 << irq));
}

inline int check_enabled(unsigned int irq) {
	uint32_t mie;
	__asm__ volatile ("csrr %0, mie" : "=r" (mie));
	return !!(mie & (1 << irq));
}

} // namespace

namespace pic {
    Pic* instance = nullptr;
}

extern "C" void default_handler() __attribute__((interrupt("machine")));

void default_handler() {
    if (pic::instance == nullptr) {
        return;
    }
    pic::instance->InterruptHandler();
}

uint32_t read_irqs() {
    if (pic::instance == nullptr) {
        return 0;
    }
    uint32_t ret = 0;
    pic::instance->irq_reg_.Read(&ret);
    return ret;
}

void Pic::InterruptHandler() {
    uint32_t cause = get_mcause();
    // Only handle Machine Timer Interrupts (which is what PIC is connected to).
    if ((cause & 0x80000000) && (cause & 0x7) == 7) {
        uart_putchar('!');
        uint32_t mask_save = 0;
        ReadMask(&mask_save);

        uint32_t irqs = 0;
        irq_reg_.Read(&irqs);

        if ((irqs & pic::kTimerIrqBit) && timer_handler_) {
            timer_handler_->InterruptHandler(this, irqs);
        }
        if ((irqs & pic::kUartIrqBit) && uart_handler_) {
            uart_handler_->InterruptHandler(this, irqs);
        }

        // Acknowledge by writing back the pending bits (check VHDL logic).
        // If your PIC VHDL clears on write of 0, this is correct.
        ClearIrq(pic::kTimerIrqBit | pic::kUartIrqBit);
    }
}


Pic::Pic(size_t base_address) : mask_(0), mask_reg_(base_address + MASK_REG),
    irq_reg_(base_address + IRQ_REG)
{
    DisableInterrupts();
    mask_reg_.Write(0);
    irq_reg_.Write(0);
    pic::instance = this;
    set_interrupt_handler(default_handler);
}

int Pic::ClearIrq(uint32_t _mask) {
    return irq_reg_.Write(0);
}

int Pic::SetMask(uint32_t mask) {
    return mask_reg_.Write(mask);
}

int Pic::ReadMask(uint32_t* mask) {
    return mask_reg_.Read(mask);
}

void Pic::EnableInterrupts() {
    enable_interrupt(kExternalTimerIrq);
}

void Pic::DisableInterrupts() {
    disable_interrupt(kExternalTimerIrq);
}

void Pic::SetTimerHandler(Timer* handler) {
    timer_handler_ = handler;
}

void Pic::SetUartHandler(Uart* handler) {
    uart_handler_ = handler;
}

void Pic::WaitForInterrupt() {
    __asm__ volatile("wfi");
}

} // namespace lib
