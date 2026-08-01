// SPDX-License-Identifier: Apache-2.0

#include "lib/reg.h"
#include <gtest/gtest.h>

namespace lib {
namespace {

class RegTest : public ::testing::Test {
protected:
    void SetUp() override {
        Reg::ClearMockValues();
    }

    void TearDown() override {
        Reg::ClearMockValues();
    }
};

TEST_F(RegTest, ReadWrite) {
    uint32_t address = 0x1000;
    uint32_t value_to_write = 0xDEADBEEF;
    uint32_t value_read = 0;

    Reg reg(address);

    // Initial value should be 0 if not set (due to std::map default)
    EXPECT_EQ(reg.Read(&value_read), 0);
    EXPECT_EQ(value_read, 0);

    // Test Write
    EXPECT_EQ(reg.Write(value_to_write), 0);

    // Verify using mock accessor
    EXPECT_EQ(Reg::GetMockValue(address), value_to_write);

    // Test Read
    EXPECT_EQ(reg.Read(&value_read), 0);
    EXPECT_EQ(value_read, value_to_write);
}

TEST_F(RegTest, SetMockValue) {
    uint32_t address = 0x2000;
    uint32_t value = 0xCAFEBABE;
    uint32_t value_read = 0;

    Reg reg(address);

    // Set mock value directly
    Reg::SetMockValue(address, value);

    // Test Read
    EXPECT_EQ(reg.Read(&value_read), 0);
    EXPECT_EQ(value_read, value);
}

TEST_F(RegTest, MultipleRegisters) {
    Reg reg1(0x3000);
    Reg reg2(0x3004);
    uint32_t val1 = 0;
    uint32_t val2 = 0;

    reg1.Write(0x1111);
    reg2.Write(0x2222);

    reg1.Read(&val1);
    reg2.Read(&val2);

    EXPECT_EQ(val1, 0x1111);
    EXPECT_EQ(val2, 0x2222);
}

} // namespace
} // namespace lib
