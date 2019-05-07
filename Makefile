all: doorsensor receiver

###########################################
# AVR toolchain detection
###########################################

# Use Arduino toolchain if available
ifeq ($(shell uname), Darwin)
ARDUINO_DIR = /Applications/Arduino.app/Contents/Java/
endif

ifneq "$(wildcard $(ARDUINO_DIR) )" ""
AVR_DIR 	= $(ARDUINO_DIR)hardware/tools/avr/
AVR_BIN 	= $(AVR_DIR)bin/
endif

AVR_CC 		= $(AVR_BIN)avr-gcc
AVR_OBJCOPY = $(AVR_BIN)avr-objcopy
AVR_OBJDUMP = $(AVR_BIN)avr-objdump
AVR_SIZE 	= $(AVR_BIN)avr-size
AVRDUDE 	= $(AVR_BIN)avrdude

###########################################
# Default ISP options
###########################################

ISP_SPEED 	= 115200
ISP_PORT 	= $(word 1, $(shell ls /dev/tty.usbmodem*))
ISP_MCU 	= $(MCU) #$(subst atmega,m,$(MCU))
ISP_TOOL 	= arduino #wiring

#AVRDUDE_ARGS = -C "$(AVR_DIR)/etc/avrdude.conf" -P $(ISP_PORT) -p $(ISP_MCU) -c $(ISP_TOOL) -b $(ISP_SPEED)
AVRDUDE_ARGS = -C "$(AVR_DIR)/etc/avrdude.conf" -P $(ISP_PORT) -p $(ISP_MCU) -c $(ISP_TOOL) -b $(ISP_SPEED)

#-v -patmega328p -carduino -P/dev/cu.usbmodem14201 -b115200 -D

###########################################
# Functions
###########################################

# Replace .c extensions to .o in $(2) and prefix the results by $(1)
TO_OBJECTS = $(addprefix $(1), $(patsubst %.c,%.o,$(2)))

###########################################
# Build configuration
###########################################

SRC			= ./
BIN			= ./bin/
OBJ         = $(BIN)$(MCU)/

CC			= $(AVR_CC)
INCLUDES	= -I "$(AVR_DIR)avr/$(MCU)/include"
CFLAGS	 	= -std=gnu99 -c -g -Os -Wall -Wextra -MMD -mmcu=$(MCU) -DF_CPU=$(F_CPU) -fno-exceptions -ffunction-sections -fdata-sections -fdiagnostics-color=auto $(INCLUDES)
LDFLAGS 	= -mmcu=$(MCU) -fdiagnostics-color=auto -Wl,-static -Wl,--gc- -finline-functions

MCU			= atmega328p
F_CPU		= 16000000

SRC_FILES_DOORSENSOR 	= doorsensor.c
SRC_FILES_RECEIVER 		= receiver.c avr-uart/uart.c rcswitch-avr/RCSwitch.c

OBJECTS_DOORSENSOR      = $(call TO_OBJECTS, $(BIN)attiny85/, $(SRC_FILES_DOORSENSOR))
OBJECTS_RECEIVER        = $(call TO_OBJECTS, $(BIN)atmega328p/, $(SRC_FILES_RECEIVER))

doorsensor: MCU			= attiny85
doorsensor: F_CPU		= 1000000
doorsensor: INCLUDES	= -I~/Library/Arduino15/packages/attiny/hardware/avr/1.0.2/variants/tiny8
doorsensor: OBJECTS 	= $(OBJECTS_DOORSENSOR)

doorsensor: $(OBJECTS_DOORSENSOR) $(BIN)doorsensor.hex

receiver: OBJECTS 	= $(OBJECTS_RECEIVER)

receiver: $(OBJECTS_RECEIVER) $(BIN)receiver.hex

doorsensor-isp: ISP_SPEED 	= 19200
doorsensor-isp: ISP_TOOL 	= arduino
doorsensor-isp: MCU			= attiny85
doorsensor-isp: avr-upload-doorsensor

doorsensor-size: MCU		= attiny85
doorsensor-size: avr-size-doorsensor

receiver-isp: avr-upload-receiver

receiver-size: avr-size-receiver

.PHONY: doorsensor receiver doorsensor-isp receiver-isp doorsensor-size receiver-size
.PRECIOUS: $(BIN)%.elf

###########################################
# Build rules
###########################################

$(BIN)atmega328p/%.o: %.c
	@mkdir -p $(shell dirname $@)
	$(CC) $< $(CFLAGS) -c -o $@

$(BIN)attiny85/%.o: %.c
	@mkdir -p $(shell dirname $@)
	$(CC) $< $(CFLAGS) -c -o $@

$(BIN)%.elf:
	@mkdir -p $(shell dirname $@)
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@

$(BIN)%.hex: $(BIN)%.elf
	@mkdir -p $(shell dirname $@)
	$(AVR_OBJCOPY) -O ihex -R .eeprom $< $@

$(BIN)%.eep: $(BIN)%.elf
	@mkdir -p $(shell dirname $@)
	$(AVR_OBJCOPY) -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings --change-section-lma .eeprom=0 $< $@

$(BIN)%.dump: $(BIN)%.hex
	$(AVR_OBJDUMP) -m avr -D $< > $@

###########################################
# AVR tool targets
###########################################

avr-upload-%:
	$(AVRDUDE) $(AVRDUDE_ARGS) $(ISP_FUSES) -U flash:w:$(BIN)$*.hex:i

avr-size-%:
	$(AVR_SIZE) --mcu=$(MCU) $(BIN)$*.elf

###########################################
# Housekeeping
###########################################

clean:
	rm -rf $(BIN)

# include deps lists build with gcc -MMD flag
ifneq "$(wildcard $(BIN) )" ""
-include $(shell find $(BIN) -name "*.d")
endif
