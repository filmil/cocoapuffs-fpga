// SPDX-License-Identifier: Apache-2.0

#ifndef LIB_IHEX_IHEX_H_
#define LIB_IHEX_IHEX_H_

#include <cstddef>

#include "kk_ihex.h"
#include "kk_ihex_read.h"

namespace lib::ihex {

extern bool gEof;
extern int line;

ihex_bool_t ihex_data_read(struct ihex_state* ihex, ihex_record_type_t type, ihex_bool_t checksum_error);

} // namespace lib::ihex

#endif // LIB_IHEX_IHEX_H_

