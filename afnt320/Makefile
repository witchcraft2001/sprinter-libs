SHELL := /bin/sh

SJASMPLUS ?= sjasmplus
PYTHON ?= python3
LIBMAN_MKDLL ?= ../../libman/.venv/bin/sprinter-mkdll
LIBMAN_DIR ?= ../../libman/libman
BUILD_DATE ?= $(shell date +%Y-%m-%d)
BUILD ?= build
SOURCE := afnt320.asm
FONT_SOURCE := font.bin
FONT_TOOL := tools/font_to_accel.py
ACCEL_FONT := $(BUILD)/font_accel.bin
DLL := $(BUILD)/AFNT320.DLL
RELEASE_DLL := AFNT320.DLL
RAW_DLL := $(BUILD)/AFNT320.raw.dll
TEST_SOURCE := test.asm
TEST_EXE := $(BUILD)/AFNT320.EXE

.PHONY: all clean inspect verify raw test release

all: $(DLL) $(TEST_EXE)

$(ACCEL_FONT): $(FONT_SOURCE) $(FONT_TOOL)
	mkdir -p $(BUILD)
	$(PYTHON) $(FONT_TOOL) $(FONT_SOURCE) $@

$(DLL): $(SOURCE) $(ACCEL_FONT) ../common/fontlayout.inc ../common/textcore320.inc
	mkdir -p $(BUILD)
	$(LIBMAN_MKDLL) build $(SOURCE) --format l0 --target 1.2 \
		--assembler sjasmplus --compress --name "AFNT320 gfx" \
		--version 1.4 --date $(BUILD_DATE) -o $@

inspect: $(DLL)
	$(LIBMAN_MKDLL) inspect $(DLL)

verify: $(DLL)
	$(LIBMAN_MKDLL) verify $(DLL) --target 1.2

release: all verify
	cp $(DLL) $(RELEASE_DLL)

raw: $(DLL)
	$(LIBMAN_MKDLL) decompress $(DLL) -o $(RAW_DLL)

test: $(TEST_EXE)

$(TEST_EXE): $(TEST_SOURCE) $(DLL) $(LIBMAN_DIR)/libman13.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --inc="$(LIBMAN_DIR)" --raw=$@ $(TEST_SOURCE)

clean:
	rm -f $(BUILD)/AFNT320.DLL $(BUILD)/AFNT320.raw.dll \
		$(BUILD)/AFNT320.EXE $(BUILD)/font_accel.bin \
		$(BUILD)/afnt320.bin $(BUILD)/afnt320.lst $(BUILD)/afnt320.sld
