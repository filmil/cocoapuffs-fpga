// SPDX-License-Identifier: Apache-2.0

/**
 * @file
 * @brief UART communication.
 */

#ifndef _LIB_UART_H
#define _LIB_UART_H

#include <cstdint>
#include <cstddef>
#include <cstdbool>

#include "lib/reg.h"

namespace lib {
    namespace uart {
        static const uint32_t kBaseAddress = 0x40000010;

    } // namespace uart

    namespace {
        static const size_t kBufferSize = 256;
    } // namespace

    class Pic;
    class Uart {
      public:
        Uart(uint32_t base_address);
        void InterruptHandler(Pic* p, uint32_t irq);

        size_t Read(char* buf, size_t len);
        int ReadLine(char* buf, size_t buf_len);

        bool IsOverrun() const { return overrun_; }
        bool IsEmpty() const { return !overrun_ && (begin_==end_); }

      private:
        Reg reg_;

        char buffer_[kBufferSize];
        volatile char* begin_ = buffer_;
        volatile char* end_ = buffer_;
        volatile bool overrun_ = false;

    };
} // namespace lib


#endif // _LIB_UART_H
