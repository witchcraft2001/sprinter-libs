SHELL := /bin/sh

SJASMPLUS ?= sjasmplus
LIBMAN_MKDLL ?= ../../libman/.venv/bin/sprinter-mkdll
BUILD ?= build
SOURCE := afnt640.asm
DLL := $(BUILD)/AFNT640.DLL
RAW_DLL := $(BUILD)/AFNT640.raw.dll
TEST_SOURCE := test.asm
TEST_EXE := $(BUILD)/AFNT640.EXE

.PHONY: all clean inspect verify raw test

all: $(DLL) $(TEST_EXE)

$(DLL): $(SOURCE) font.bin
	mkdir -p $(BUILD)
	$(LIBMAN_MKDLL) build $(SOURCE) --format l0 --target 1.2 \
		--assembler sjasmplus --compress --name "AFNT640 gfx" \
		--version 1.3 --date 2026-07-27 -o $@

inspect: $(DLL)
	$(LIBMAN_MKDLL) inspect $(DLL)

verify: $(DLL)
	$(LIBMAN_MKDLL) verify $(DLL) --target 1.2

raw: $(DLL)
	$(LIBMAN_MKDLL) decompress $(DLL) -o $(RAW_DLL)

test: $(TEST_EXE)

$(TEST_EXE): $(TEST_SOURCE) $(DLL) ../../../sprinter-rtl8019a/src/lib/libman13.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --raw=$@ $(TEST_SOURCE)

clean:
	rm -f $(BUILD)/AFNT640.DLL $(BUILD)/AFNT640.raw.dll \
		$(BUILD)/AFNT640.EXE $(BUILD)/afnt640.bin $(BUILD)/afnt640.lst $(BUILD)/afnt640.sld
