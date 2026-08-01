// SPDX-License-Identifier: Apache-2.0

#include "lib/uart/uart.h"
#include <gtest/gtest.h>

namespace lib {
namespace {

TEST(UartTest, IsEmpty) {
    // Test with empty bit set
    EXPECT_TRUE(uart_is_empty(EMPTY_BITMASK));
    EXPECT_TRUE(uart_is_empty(EMPTY_BITMASK | 0xFF));
    EXPECT_TRUE(uart_is_empty(EMPTY_BITMASK | FULL_BITMASK));

    // Test with empty bit not set
    EXPECT_FALSE(uart_is_empty(0));
    EXPECT_FALSE(uart_is_empty(0xFF));
    EXPECT_FALSE(uart_is_empty(FULL_BITMASK));
}

TEST(UartTest, IsFull) {
    // Test with full bit set
    EXPECT_TRUE(uart_is_full(FULL_BITMASK));
    EXPECT_TRUE(uart_is_full(FULL_BITMASK | 0xFF));
    EXPECT_TRUE(uart_is_full(FULL_BITMASK | EMPTY_BITMASK));

    // Test with full bit not set
    EXPECT_FALSE(uart_is_full(0));
    EXPECT_FALSE(uart_is_full(0xFF));
    EXPECT_FALSE(uart_is_full(EMPTY_BITMASK));
}

TEST(UartTest, PauseForSpins) {
    // We can't easily measure the exact number of spins, but we can
    // at least ensure it doesn't crash or hang for some values.
    pause_for_spins(0);
    pause_for_spins(1);
    pause_for_spins(100);
}

} // namespace
} // namespace lib
