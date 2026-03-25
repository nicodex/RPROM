/*
 * RPROM firmware
 *
 * Copyright (C) 2025 Niklas Ekström
 */
#include "pico/multicore.h"
#include "pico/unique_id.h"
#include "hardware/clocks.h"
#include "hardware/dma.h"
#include "hardware/flash.h"
#include "hardware/gpio.h"
#include "hardware/structs/busctrl.h"
#include "hardware/structs/xip.h"
#include "hardware/structs/xip_aux.h"
#include "hardware/sync.h"

#include "firmware/version.h"
#include "protocol.h"
#include "rprom_r1.pio.h"

#include <string.h>

#define DATA_MASK ((1 << RPROM_DATA_PIN_COUNT) - 1)
#define ADDR_MASK ((1 << RPROM_ADDR_PIN_COUNT) - 1)

#define ROM_SLOT_SIZE (512 * 1024)

__attribute__((section(".rom_image")))
__attribute__((aligned(ROM_SLOT_SIZE)))
static uint16_t rom_image[ROM_SLOT_SIZE / 2];

#define CONFIG_SECTOR_OFFSET    (ROM_SLOT_SIZE - FLASH_SECTOR_SIZE)
#define CONFIG_SECTOR_BASE      (XIP_BASE + CONFIG_SECTOR_OFFSET)

struct ConfigTuple
{
    uint32_t rom_slot;
    uint32_t reserved;
};

struct ConfigPage
{
    uint32_t pages_bitmap;
    uint32_t tuples_bitmap;
    struct ConfigTuple tuples[31];
};

static inline uint32_t get_active_rom_slot()
{
    struct ConfigPage *pages = (struct ConfigPage *)CONFIG_SECTOR_BASE;
    uint32_t active_page = __builtin_ctz(pages[0].pages_bitmap);
    uint32_t active_tuple = __builtin_ctz(pages[active_page].tuples_bitmap);
    uint32_t rom_slot = pages[active_page].tuples[active_tuple].rom_slot;
    return (rom_slot == 0 || rom_slot >= 8) ? 1 : rom_slot;
}

static void update_active_rom_slot_in_flash(uint32_t rom_slot)
{
    struct ConfigPage *pages = (struct ConfigPage *)CONFIG_SECTOR_BASE;
    uint32_t active_page = __builtin_ctz(pages[0].pages_bitmap);
    uint32_t active_tuple = __builtin_ctz(pages[active_page].tuples_bitmap);

    active_tuple++;
    if (active_tuple >= 31)
    {
        active_tuple = 0;
        active_page++;
        if (active_page >= 16)
        {
            active_page = 0;
            flash_range_erase(CONFIG_SECTOR_OFFSET, FLASH_SECTOR_SIZE);
        }
    }

    // Uses 256 bytes of stack space.
    struct ConfigPage page;
    memcpy(&page, (const void *)&pages[active_page], sizeof(page));

    page.pages_bitmap = ~((1 << active_page) - 1);
    page.tuples_bitmap = ~((1 << active_tuple) - 1);
    page.tuples[active_tuple].rom_slot = rom_slot;

    flash_range_program(CONFIG_SECTOR_OFFSET + active_page * FLASH_PAGE_SIZE,
                        (const uint8_t *)&page, FLASH_PAGE_SIZE);

    if (active_page != 0)
    {
        memcpy(&page, (const void *)&pages[0], FLASH_PAGE_SIZE);
        page.pages_bitmap = ~((1 << active_page) - 1);
        flash_range_program(CONFIG_SECTOR_OFFSET, (const uint8_t *)&page, FLASH_PAGE_SIZE);
    }
}

static void handle_magic_read(uint32_t address)
{
    uint32_t cmd = address >> 14;
    uint32_t arg = address & ((1 << 14) - 1);

    switch (cmd)
    {
        case CMD_UPDATE_ACTIVE_ROM_SLOT:
        {
            uint32_t rom_slot = arg;
            if (rom_slot == 0 || rom_slot > 7)
                return;

            update_active_rom_slot_in_flash(rom_slot);

            uint32_t rom_slot_base = XIP_BASE + rom_slot * ROM_SLOT_SIZE;
            memcpy(rom_image, (const void *)rom_slot_base, sizeof(rom_image));
            break;
        }
        case CMD_WRITE_STATUS_TO_SRAM:
        {
            struct StatusV1 *status = (struct StatusV1 *)rom_image;
            *status = (struct StatusV1) {
                .magic = STATUS_V1_MAGIC,
                .status_length = sizeof(struct StatusV1),
                .major_version = RPROM_FIRMWARE_VERSION_MAJOR,
                .minor_version = RPROM_FIRMWARE_VERSION_MINOR,
                .patch_version = RPROM_FIRMWARE_VERSION_PATCH,
                .flash_size_mb = 4,
                .active_rom_slot = (uint8_t)get_active_rom_slot(),
            };
            break;
        }
        case CMD_RESTORE_PAGE_TO_SRAM:
        {
            const uint32_t rom_slot = get_active_rom_slot();
            const uint32_t rom_slot_base = XIP_BASE + rom_slot * ROM_SLOT_SIZE;
            memcpy(rom_image, (const void *)rom_slot_base, FLASH_PAGE_SIZE + 2);
            break;
        }
        case CMD_COPY_PAGE_AMIGA_TO_SRAM:
        {
            for (int i = 0; i < 128; i++)
                rom_image[i] = __builtin_bswap16((uint16_t)multicore_fifo_pop_blocking_inline());

            break;
        }
        case CMD_COPY_PAGE_FLASH_TO_SRAM:
        {
            rom_image[128] = 0xffff;
            memcpy(rom_image, (const void *)(XIP_BASE + arg * FLASH_PAGE_SIZE), FLASH_PAGE_SIZE);
            rom_image[128] = 0;
            break;
        }
        case CMD_COPY_PAGE_SRAM_TO_FLASH:
        {
            rom_image[128] = 0xffff;
            flash_range_program(arg * FLASH_PAGE_SIZE, (const uint8_t *)rom_image, FLASH_PAGE_SIZE);
            rom_image[128] = 0;
            break;
        }
        case CMD_ERASE_FLASH_SECTOR:
        {
            rom_image[128] = 0xffff;
            flash_range_erase(arg * FLASH_SECTOR_SIZE, FLASH_SECTOR_SIZE);
            rom_image[128] = 0;
            break;
        }
    }
}

static void __not_in_flash_func(slot_transfer_from_flash_now)(uint slot_nr)
{
    // PIO DMA rx/tx would be blocked by other DMA (even if not high priority)
    // but, the auxiliary XIP streaming DMA does not conflict with PIO DMAs...
    uint const channel = NUM_DMA_CHANNELS - 1;
    while (!(xip_ctrl_hw->stat & XIP_STAT_FIFO_EMPTY_BITS))
        (void)xip_ctrl_hw->stream_fifo;
    xip_ctrl_hw->stream_addr = XIP_BASE + (slot_nr * ROM_SLOT_SIZE);
    xip_ctrl_hw->stream_ctr = ROM_SLOT_SIZE / 4;
    dma_channel_config config = dma_channel_get_default_config(channel);
    channel_config_set_read_increment(&config, false);
    channel_config_set_write_increment(&config, true);
    channel_config_set_dreq(&config, DREQ_XIP_STREAM);
    dma_channel_configure(channel, &config, rom_image,
        (const void *)(XIP_AUX_BASE + XIP_AUX_STREAM_OFFSET),
        dma_encode_transfer_count(ROM_SLOT_SIZE / 4), true);
    dma_channel_wait_for_finish_blocking(channel);
}

static void __not_in_flash_func(core1_main)()
{
#ifndef RPROM_PIO_DMA
    // PIO CPU rx/tx requires high priority for cpu0 (over DMA and cpu1)
    busctrl_hw->priority = BUSCTRL_BUS_PRIORITY_PROC0_BITS;
    while (!busctrl_hw->priority_ack) tight_loop_contents();
#endif
    // stress the system by permanently copying from XIP/flash to SRAM
    while (true) {
        slot_transfer_from_flash_now(1);
    }
 }

static void __not_in_flash_func(core0_main)()
{
#ifdef RPROM_PIO_DMA
    while (true) {
        __wfi();
    }
#else
    PIO const data_pio = PIO_INSTANCE(data_pio_inst);
    PIO const addr_pio = PIO_INSTANCE(addr_pio_inst);
    while (!pio_sm_is_tx_fifo_empty(addr_pio, addr_pio_sm))
        tight_loop_contents();
    while(true) {
        // if (!pio_sm_is_rx_fifo_empty(addr_pio, addr_pio_sm)) continue;
        // replaced with: !(is there any TX or RX in any SM of the whole PIO)
        // multiple/unrolled checks because cbnz can only do forward branches
        if (!addr_pio->flevel
            && !addr_pio->flevel && !addr_pio->flevel && !addr_pio->flevel
            && !addr_pio->flevel && !addr_pio->flevel && !addr_pio->flevel
            && !addr_pio->flevel && !addr_pio->flevel && !addr_pio->flevel
            ) {
            continue;
        }
        uintptr_t const addr = pio_sm_get(addr_pio, addr_pio_sm);
        uint16_t const data = __builtin_bswap16(*(uint16_t *)addr);
        // pio_sm_put(data_pio, data_pio_sm, data);
        // RP2350 Datasheet - 2.1.5. Narrow IO register writes
        *(io_wo_16 *)(&data_pio->txf[data_pio_sm]) = data;
    }
#endif
}

// Should be the same as the USB FAT partition UUID
// (generated from the OTP or flash serial number):
//  $ picotool info -d \
//  | sed -n -e 's/^.*chipid:.*0x\(.*\)$/RPROM_SERIAL=\1/p'
//  RPROM_SERIAL=87ad2282b1a22463
//  $ printf 'RPROM_UUID=%08x\n' \
//    "$((0x87ad2282 * 31 + 0xb1a22463 & 0xffffffff))"
//  RPROM_UUID=1f995221
//  $ udevadm info --query=property \
//    --property=ID_USB_SERIAL_SHORT,ID_FS_UUID \
//    --name=/dev/sdb1
//  ID_USB_SERIAL_SHORT=87AD2282B1A22463
//  ID_FS_UUID=1F99-5221
static uint32_t __not_in_flash_func(get_serial_number32)()
{
    struct chip_id_t {
        uint32_t public_rand_id[2];
    } chip_id;
    static_assert(sizeof(chip_id) == sizeof(pico_unique_board_id_t), "");
    pico_get_unique_board_id((pico_unique_board_id_t *)&chip_id);
    return chip_id.public_rand_id[1] * 31 + chip_id.public_rand_id[0];
}

void __not_in_flash_func(main)()
{
    // Be careful with system clock and flash access speed
    // (if PICO_CLOCK_ADJUST_PERI_CLOCK_WITH_SYS_CLOCK set
    // W25Q32RVXH sck <= 133HMz, ZD25WQ32CE sck <= 104MHz)
    set_sys_clock_khz(200000, false);  // 5ns

    gpio_set_dir_in_masked64(
        (1ull << RPROM_BYTE_PIN) |
        (1ull << RPROM_RESET_PIN) |
        0ull);
    gpio_set_function(RPROM_BYTE_PIN, GPIO_FUNC_SIO);
    gpio_set_pulls(RPROM_BYTE_PIN, true, true);  // bus keeper mode
    gpio_set_function(RPROM_RESET_PIN, GPIO_FUNC_SIO);
    gpio_set_pulls(RPROM_RESET_PIN, true, true);  // bus keeper mode
    gpio_set_drive_strength(RPROM_RESET_PIN, GPIO_DRIVE_STRENGTH_12MA);

    addr_data_program_init(rom_image);
    slot_transfer_from_flash_now(1); //FIXME: test always slot 1

    multicore_launch_core1(core1_main);
    core0_main();
}
