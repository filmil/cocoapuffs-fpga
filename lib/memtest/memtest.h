// SPDX-License-Identifier: Apache-2.0

#ifndef _LIB_MEMTEST_MEMTEST_H
#define _LIB_MEMTEST_MEMTEST_H

#include <cstdint>
#include <cstddef>

namespace lib {

struct Result {
  bool ok{};
  uintptr_t addr{};
  uint32_t expected{};
  uint32_t actual{};
};

class Memtest {
  public:
    Memtest(uintptr_t base_address, uint32_t base_pattern, uint32_t cell_count);

    /// Returns false if the test fails, true otherwise.
    Result Test();
  private:
    uintptr_t base_address_;
    uint32_t base_pattern_;
    uint32_t cell_count_;
};

bool TestOneCell(uint32_t expected, size_t cell);

bool TestWithC(uint32_t value, size_t limit);

} // namespace lib
#endif // _LIB_MEMTEST_MEMTEST_H
