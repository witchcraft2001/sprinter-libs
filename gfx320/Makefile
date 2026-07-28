SHELL := /bin/sh

SJASMPLUS ?= sjasmplus
LIBMAN_MKDLL ?= ../../libman/.venv/bin/sprinter-mkdll
LIBMAN_DIR ?= ../../../sprinter-rtl8019a/src/lib
BUILD_DATE ?= $(shell date +%Y-%m-%d)
BUILD ?= build
DLL := $(BUILD)/GFX320.DLL
RELEASE_DLL := GFX320.DLL
RAW_DLL := $(BUILD)/GFX320.raw.dll
TEST_EXE := $(BUILD)/GFX320.EXE

.PHONY: all clean inspect verify raw test release

all: $(DLL) $(TEST_EXE)

$(DLL): gfx320.asm
	mkdir -p $(BUILD)
	$(LIBMAN_MKDLL) build $< --format l0 --target 1.2 --assembler sjasmplus \
		--compress --name "GFX320 graphics" --version 1.0 --date $(BUILD_DATE) -o $@

$(TEST_EXE): test.asm gfx320.inc $(DLL) $(LIBMAN_DIR)/libman13.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --inc="$(LIBMAN_DIR)" --raw=$@ test.asm

test: $(TEST_EXE)

inspect: $(DLL)
	$(LIBMAN_MKDLL) inspect $(DLL)

verify: $(DLL)
	$(LIBMAN_MKDLL) verify $(DLL) --target 1.2

release: verify
	cp $(DLL) $(RELEASE_DLL)

raw: $(DLL)
	$(LIBMAN_MKDLL) decompress $(DLL) -o $(RAW_DLL)

clean:
	rm -f $(DLL) $(RAW_DLL) $(TEST_EXE) $(BUILD)/gfx320.*
