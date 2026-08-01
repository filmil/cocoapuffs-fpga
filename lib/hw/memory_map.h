// SPDX-License-Identifier: Apache-2.0

#ifndef LIB_HW_MEMORY_MAP_H_
#define LIB_HW_MEMORY_MAP_H_

#ifndef LIB_HW_MEMORY_BASE
#error LIB_HW_MEMORY_BASE not defined, must be a hex integer.
#endif

#include <cstdint>

namespace lib::hw {

static constexpr uint32_t kMemoryBase = (LIB_HW_MEMORY_BASE);

void* MemStart();

uint32_t* MemStartPtr();

} // namespace lib::hw

#endif // LIB_HW_MEMORY_MAP_H_
