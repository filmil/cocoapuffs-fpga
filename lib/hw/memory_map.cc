#include "lib/hw/memory_map.h"

#include <cstdint>

namespace lib::hw {

void* MemStart() {
    return reinterpret_cast<void*>(kMemoryBase);
}

uint32_t* MemStartPtr() {
    return reinterpret_cast<uint32_t*>(kMemoryBase);
}

}  // namespace lib::hw
