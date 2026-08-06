SHELL := /bin/sh

SJASMPLUS ?= sjasmplus
PYTHON ?= python3
LIBMAN_MKDLL ?= ../../libman/.venv/bin/sprinter-mkdll
LIBMAN_DIR ?= ../../libman/libman
BUILD_DATE ?= $(shell date +%Y-%m-%d)
BUILD ?= build
SOURCE := afnt640.asm
DLL := $(BUILD)/AFNT640.DLL
RELEASE_DLL := AFNT640.DLL
RAW_DLL := $(BUILD)/AFNT640.raw.dll
TEST_SOURCE := test.asm
TEST_EXE := $(BUILD)/AFNT640.EXE

.PHONY: all clean inspect verify raw test host-test z80-test release

all: $(DLL) $(TEST_EXE)

$(DLL): $(SOURCE) afnt640.inc font.bin ../common/afnt_target.inc ../common/afnt_runtime.inc
	mkdir -p $(BUILD)
	$(LIBMAN_MKDLL) build $(SOURCE) --format l0 --target 1.2 \
		--assembler sjasmplus --compress --name "AFNT640 gfx" \
		--version 1.5 --date $(BUILD_DATE) -o $@

inspect: $(DLL)
	$(LIBMAN_MKDLL) inspect $(DLL)

verify: $(DLL)
	$(LIBMAN_MKDLL) verify $(DLL) --target 1.2

release: all verify host-test z80-test
	cp $(DLL) $(RELEASE_DLL)

raw: $(DLL)
	$(LIBMAN_MKDLL) decompress $(DLL) -o $(RAW_DLL)

test: $(TEST_EXE)

$(TEST_EXE): $(TEST_SOURCE) afnt640.inc ../common/load_library.inc $(DLL) $(LIBMAN_DIR)/libman13.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --inc="$(LIBMAN_DIR)" --raw=$@ $(TEST_SOURCE)

host-test: $(DLL)
	$(PYTHON) -m unittest discover -s tests -v

z80-test: $(DLL)
	LIBMAN_DIR="$(LIBMAN_DIR)" tools/run_z80_tests.sh

clean:
	rm -f $(BUILD)/AFNT640.DLL $(BUILD)/AFNT640.raw.dll \
		$(BUILD)/AFNT640.EXE $(BUILD)/afnt640.bin $(BUILD)/afnt640.lst $(BUILD)/afnt640.sld
	rm -f $(BUILD)/z80-tests/*
