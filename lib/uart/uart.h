// SPDX-License-Identifier: Apache-2.0

/**
 * @file
 * @brief UART communication.
 */

#ifndef _LIB_UART_UART_H
#define _LIB_UART_UART_H

#include <cstdint>
#include <cstddef>
#include <cstdbool>

#ifdef __cplusplus
extern "C" {
#endif

// If set, the read path of the UART is empty.
#define EMPTY_BITMASK (0x0100)
// If set, the write path of the UART is full.
#define FULL_BITMASK (0x0800)

/**
 * @brief Pauses execution for a number of spins.
 * @param pause The number of spins to pause for.
 */
void pause_for_spins(uint32_t pause);

/**
 * @brief Checks if the UART is empty.
 * @param c The value to check.
 * @return True if the UART is empty, false otherwise.
 */
bool uart_is_empty(uint32_t c);

/**
 * @brief Checks if the UART is full.
 * @param c The value to check.
 * @return True if the UART is full, false otherwise.
 */
bool uart_is_full(uint32_t c);

/**
 * @brief Gets a character from the UART. Blocks until a char is received.
 * @param c A pointer to a char to store the character.
 */
volatile void uart_getchar(char* c);

/**
 * @brief Waits for the UART to be available.
 */
void uart_wait_available();

/**
 * @brief Puts a character to the UART.
 * @param c The character to put.
 */
void uart_putchar(char c);

/**
 * @brief Prints a string to the UART.
 * @param str The string to print.
 * @return The number of characters printed.
 */
int uart_print(const char *str);

// Comments TBD.
void printme(const char* p);
int printmef(const char *format, ...);
int kprintf(const char *format, ...);
bool uart_getline(char *buf, size_t read_chars);

#ifdef __cplusplus
}
#endif

#endif // _LIB_UART_UART_H
