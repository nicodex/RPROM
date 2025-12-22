cmake_minimum_required(VERSION 3.17...3.27)

set(PICO_BOARD none)
set(PICO_PLATFORM rp2350)
set(PICO_FLASH_SIZE_BYTES 4194304)
set(PICO_RP2350_A2_SUPPORTED 1)
include(pico_sdk_import.cmake)

project(rprom_project
  VERSION 0.0.0 # FIXME: update before merge/release
  LANGUAGES C CXX ASM
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

configure_file(version.h.in generated/rprom/version.h @ONLY)
configure_file(version.i.in generated/rprom/version.i @ONLY)

add_executable(rprom
  rprom.c
  protocol.h
  ${CMAKE_CURRENT_BINARY_DIR}/generated/rprom/version.h
)

pico_set_linker_script(rprom ${CMAKE_CURRENT_LIST_DIR}/memmap_custom.ld)

pico_enable_stdio_usb(rprom 0)
pico_enable_stdio_uart(rprom 0)

pico_add_extra_outputs(rprom)

target_compile_definitions(rprom PRIVATE
  PICO_RP2350A=0
  PICO_BOOT_STAGE2_CHOOSE_W25Q080=1
  PICO_FLASH_SPI_CLKDIV=2
  PICO_RP2350_A2_SUPPORTED=1
  PICO_HEAP_SIZE=0
  PICO_CORE1_STACK_SIZE=3072
  PICO_STACK_SIZE=1024
  PICO_TIME_DEFAULT_ALARM_POOL_DISABLED=1
)

target_include_directories(rprom
  PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}/generated
)

target_link_libraries(rprom
  pico_stdlib
  pico_multicore
  hardware_flash
)
