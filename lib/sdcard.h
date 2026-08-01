// SPDX-License-Identifier: Apache-2.0

/**
 * @file
 * @brief SD Card SPI Driver for Wishbone lite peripheral.
 *
 * This file contains the declaration of the SDCard class, which provides
 * an interface to talk to the SD card via the sdcard_wblite peripheral.
 */

#ifndef _LIB_SDCARD_H
#define _LIB_SDCARD_H

#include <cstdint>
#include <cstddef>

#include "lib/reg.h"

namespace lib {

/**
 * @brief SD Card driver over SPI.
 * @tparam BASE_ADDRESS Base address of the sdcard_wblite peripheral.
 */
template <uint32_t BASE_ADDRESS>
class SDCard {
    public:
        /**
         * @brief Constructs an SDCard object.
         */
        SDCard() : data_reg_(BASE_ADDRESS), ctrl_reg_(BASE_ADDRESS + 4) {}

        /**
         * @brief Initializes the SD card.
         * @return 0 on success, or a negative error code.
         */
        int Init();

        /**
         * @brief Reads a 512-byte block from the SD card.
         * @param block_addr Block address to read.
         * @param buffer Pointer to a 512-byte buffer to store the data.
         * @return 0 on success, or a negative error code.
         */
        int ReadBlock(uint32_t block_addr, uint8_t* buffer);

    private:
        Reg data_reg_;
        Reg ctrl_reg_;

        uint8_t Transfer(uint8_t data);
        void Select();
        void Deselect();
        int SendCommand(uint8_t cmd, uint32_t arg, uint8_t crc);
};

// SD Card Commands
namespace sdcard_commands {
    constexpr uint8_t CMD0 = 0x40; // GO_IDLE_STATE
    constexpr uint8_t CMD8 = 0x48; // SEND_IF_COND
    constexpr uint8_t CMD17 = 0x51; // READ_SINGLE_BLOCK
    constexpr uint8_t CMD55 = 0x77; // APP_CMD
    constexpr uint8_t ACMD41 = 0x69; // SD_SEND_OP_COND
}

template <uint32_t BASE_ADDRESS>
uint8_t SDCard<BASE_ADDRESS>::Transfer(uint8_t data) {
    data_reg_.Write(data);
    uint32_t ctrl = 0;
    do {
        ctrl_reg_.Read(&ctrl);
    } while ((ctrl & 2) != 0); // Wait for busy bit to clear

    uint32_t rx = 0;
    data_reg_.Read(&rx);
    return rx & 0xFF;
}

template <uint32_t BASE_ADDRESS>
void SDCard<BASE_ADDRESS>::Select() {
    uint32_t ctrl = 0;
    ctrl_reg_.Read(&ctrl);
    ctrl &= ~1; // Clear CS_N bit (active low)
    ctrl_reg_.Write(ctrl);
}

template <uint32_t BASE_ADDRESS>
void SDCard<BASE_ADDRESS>::Deselect() {
    uint32_t ctrl = 0;
    ctrl_reg_.Read(&ctrl);
    ctrl |= 1; // Set CS_N bit
    ctrl_reg_.Write(ctrl);
    Transfer(0xFF); // Extra clock cycles after deselect
}

template <uint32_t BASE_ADDRESS>
int SDCard<BASE_ADDRESS>::SendCommand(uint8_t cmd, uint32_t arg, uint8_t crc) {
    Transfer(0xFF);
    Transfer(cmd);
    Transfer((arg >> 24) & 0xFF);
    Transfer((arg >> 16) & 0xFF);
    Transfer((arg >> 8) & 0xFF);
    Transfer(arg & 0xFF);
    Transfer(crc);

    for (int i = 0; i < 10; ++i) {
        uint8_t res = Transfer(0xFF);
        if ((res & 0x80) == 0) {
            return res;
        }
    }
    return -1;
}

template <uint32_t BASE_ADDRESS>
int SDCard<BASE_ADDRESS>::Init() {
    // Set clock divider (e.g., 100 for initial slow clock, depends on system clock)
    uint32_t ctrl = (100 << 16) | 1;
    ctrl_reg_.Write(ctrl);

    // Send dummy clocks (at least 74)
    for (int i = 0; i < 10; ++i) {
        Transfer(0xFF);
    }

    Select();

    // GO_IDLE_STATE
    if (SendCommand(sdcard_commands::CMD0, 0, 0x95) != 0x01) {
        Deselect();
        return -1; // Failed to go idle
    }

    // SEND_IF_COND
    if (SendCommand(sdcard_commands::CMD8, 0x000001AA, 0x87) == 0x01) {
        Transfer(0xFF);
        Transfer(0xFF);
        Transfer(0xFF);
        Transfer(0xFF);
    }

    // SD_SEND_OP_COND (ACMD41)
    int retries = 10000;
    do {
        SendCommand(sdcard_commands::CMD55, 0, 0xFF);
        if (SendCommand(sdcard_commands::ACMD41, 0x40000000, 0xFF) == 0) {
            break;
        }
        retries--;
    } while (retries > 0);

    if (retries == 0) {
        Deselect();
        return -2; // Timeout
    }

    Deselect();

    // Set faster clock divider for normal operation
    ctrl = (2 << 16) | 1; // Faster clock
    ctrl_reg_.Write(ctrl);

    return 0;
}

template <uint32_t BASE_ADDRESS>
int SDCard<BASE_ADDRESS>::ReadBlock(uint32_t block_addr, uint8_t* buffer) {
    if (!buffer) return -1;

    Select();

    if (SendCommand(sdcard_commands::CMD17, block_addr, 0xFF) != 0x00) {
        Deselect();
        return -1;
    }

    // Wait for data token (0xFE)
    int retries = 10000;
    uint8_t token;
    do {
        token = Transfer(0xFF);
        if (token == 0xFE) break;
        retries--;
    } while (retries > 0);

    if (retries == 0) {
        Deselect();
        return -2; // Timeout
    }

    // Read 512 bytes
    for (int i = 0; i < 512; ++i) {
        buffer[i] = Transfer(0xFF);
    }

    // Discard CRC (2 bytes)
    Transfer(0xFF);
    Transfer(0xFF);

    Deselect();
    return 0;
}

} // namespace lib

#endif // _LIB_SDCARD_H
