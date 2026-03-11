#ifndef _BOARDS_RPROM_R1_H
#define _BOARDS_RPROM_R1_H

pico_board_cmake_set(PICO_PLATFORM, rp2350)

// For board detection
#define RPROM_R1

// --- RP2350 VARIANT ---
#define PICO_RP2350A 0

// no PICO_DEFAULT_UART
// no PICO_DEFAULT_LED_PIN
// no PICO_DEFAULT_WS2812_PIN
// no PICO_DEFAULT_I2C
// no PICO_DEFAULT_SPI

// --- rprom.pio ---

#define RPROM_DATA_PIN_BASE 0
#define RPROM_DATA_PIN_COUNT 16
#define RPROM_ADDR_PIN_BASE 16
#define RPROM_ADDR_PIN_COUNT 18
#define RPROM_BYTE_PIN 34
#define RPROM_CE_PIN 35
#define RPROM_OE_PIN 36
#define RPROM_RESET_PIN 37

// --- FLASH ---

#define PICO_BOOT_STAGE2_CHOOSE_W25Q080 1
#ifndef PICO_FLASH_SPI_CLKDIV
#define PICO_FLASH_SPI_CLKDIV 2
#endif
#ifndef PICO_FLASH_SPI_RXDELAY
#define PICO_FLASH_SPI_RXDELAY 2
#endif

pico_board_cmake_set_default(PICO_FLASH_SIZE_BYTES, (4 * 1024 * 1024))
#ifndef PICO_FLASH_SIZE_BYTES
#define PICO_FLASH_SIZE_BYTES (4 * 1024 * 1024)
#endif

pico_board_cmake_set_default(PICO_RP2350_A2_SUPPORTED, 0)
#ifndef PICO_RP2350_A2_SUPPORTED
#define PICO_RP2350_A2_SUPPORTED 0
#endif

#endif
