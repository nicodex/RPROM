#ifndef BOARDS_RPROM_R1_H_INCLUDED
#define BOARDS_RPROM_R1_H_INCLUDED

#include "rprom.h"

#define RPROM_R1

#ifdef RPROM_DATA_PIN_BASE
#error "RPROM gpio routing already defined (board revs are mutually exclusive)"
#endif

#define RPROM_DATA_PIN_BASE 0
#define RPROM_DATA_PIN_COUNT 16
#define RPROM_ADDR_PIN_BASE 16
#define RPROM_ADDR_PIN_COUNT 18
#define RPROM_BYTE_PIN 34
#define RPROM_CE_PIN 35
#define RPROM_OE_PIN 36
#define RPROM_RESET_PIN 37

#endif
