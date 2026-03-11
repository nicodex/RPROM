cmake_minimum_required(VERSION 3.17...3.27)

set(PICO_BOARD_HEADER_DIRS ${CMAKE_CURRENT_LIST_DIR}/boards)
set(PICO_BOARD rprom_r1)
include(pico_sdk_import.cmake)

project(rprom_firmware
  VERSION 0.0.0 # FIXME: update before merge/release
  LANGUAGES C CXX ASM
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

configure_file(version.h.in generated/firmware/version.h @ONLY)
configure_file(version.i.in generated/firmware/version.i @ONLY)

add_executable(rprom
  rprom.c
  protocol.h
  ${CMAKE_CURRENT_BINARY_DIR}/generated/firmware/version.h
)

pico_add_extra_outputs(rprom)
pico_enable_stdio_uart(rprom 0)
pico_enable_stdio_usb(rprom 0)
pico_generate_pio_header(rprom ${CMAKE_CURRENT_LIST_DIR}/rprom.pio)
pico_set_linker_script(rprom ${CMAKE_CURRENT_LIST_DIR}/rprom.ld)
target_compile_definitions(rprom
  PRIVATE
    PICO_HEAP_SIZE=0
    PICO_CORE1_STACK_SIZE=3072
    PICO_STACK_SIZE=1024
    PICO_TIME_DEFAULT_ALARM_POOL_DISABLED=1
    PICO_MINIMAL_STORED_VECTOR_TABLE=1
    PICO_NUM_IRQ_HANDLERS=46 # RP2350 SPARE_IRQ_0
    PICO_CLOCK_ADJUST_PERI_CLOCK_WITH_SYS_CLOCK=1
)

target_include_directories(rprom
  PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}/generated
)

target_link_libraries(rprom
  PRIVATE
    pico_stdlib
    pico_multicore
    hardware_dma
    hardware_flash
    hardware_pio
)
