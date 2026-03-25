cmake_minimum_required(VERSION 3.17...3.27)

if(NOT RPROM_TARGET)
  set(RPROM_TARGET rprom_r1)
endif()

set(PICO_BOARD ${RPROM_TARGET})
set(PICO_BOARD_HEADER_DIRS ${CMAKE_CURRENT_LIST_DIR}/boards)
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

add_executable(${RPROM_TARGET}
  rprom.c
  protocol.h
  ${CMAKE_CURRENT_BINARY_DIR}/generated/firmware/version.h
)

pico_add_extra_outputs(${RPROM_TARGET})
pico_enable_stdio_uart(${RPROM_TARGET} 0)
pico_enable_stdio_usb(${RPROM_TARGET} 0)
pico_set_linker_script(${RPROM_TARGET} ${CMAKE_CURRENT_LIST_DIR}/rprom.ld)
pico_generate_pio_header(${RPROM_TARGET} ${CMAKE_CURRENT_LIST_DIR}/${RPROM_TARGET}.pio)
target_compile_definitions(${RPROM_TARGET}
  PRIVATE
    PICO_HEAP_SIZE=0
    PICO_CORE1_STACK_SIZE=3072
    PICO_STACK_SIZE=1024
    PICO_TIME_DEFAULT_ALARM_POOL_DISABLED=1
    PICO_MINIMAL_STORED_VECTOR_TABLE=1
    PICO_NUM_IRQ_HANDLERS=46 # RP2350 SPARE_IRQ_0
    PICO_CLOCK_ADJUST_PERI_CLOCK_WITH_SYS_CLOCK=1
    RPROM_PIO_DMA # comment out for RPROM_PIO_CPU
)

target_include_directories(${RPROM_TARGET}
  PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}/generated
)

target_link_libraries(${RPROM_TARGET}
  PRIVATE
    pico_stdlib
    pico_multicore
    pico_unique_id
    hardware_dma
    hardware_flash
    hardware_pio
)

unset(RPROM_TARGET CACHE)
