
#include "lib/pic.h"
#include "lib/uart.h"
#include "lib/uart/uart.h"

namespace lib {
    namespace {
        static const uint32_t kReg = 0;

	static const uint32_t kUartIrqNum = 1 << 1;
    } // namespace

Uart::Uart(uint32_t base_address) : reg_(base_address + kReg) {}

void Uart::InterruptHandler(Pic* p, uint32_t irq) {
    uint32_t status = 0;
    char uart_ch = 0;
    for(;;) {
      reg_.Read(&status);
      if (uart_is_empty(status)) {
	  break;
      }
      uart_ch = static_cast<char>(status & 0xff);
      *begin_++ = uart_ch;
      if (begin_ == buffer_ + kBufferSize) {
	  begin_ = buffer_;
      }
      if (begin_ == end_) {
	  overrun_ = true;
	  break;
      }
    }
}

size_t Uart::Read(char* buf, size_t len) {
    size_t read_count = 0;
    while (begin_ != end_ && read_count < len) {
	*buf++ = *end_;
	read_count++;
	if (end_ == buffer_ + kBufferSize) {
	    end_ = buffer_;
	}
    }
    return read_count;
}

int Uart::ReadLine(char* buf, size_t len) {
    char* cbuf = buf;
    while (len > 0) {
	// Busy-wait until there is something in the buffer.
	while (IsEmpty()) {}
	if (IsOverrun()) {
	    return -1;
	}
	len -= Read(cbuf++, 1);
	if (cbuf[-1] == '\r') {
	    break;
	}
    }
    return 0;
}

} //
