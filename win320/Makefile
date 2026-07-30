SHELL := /bin/sh

SJASMPLUS ?= sjasmplus
PYTHON ?= python3
LIBMAN_MKDLL ?= ../../libman/.venv/bin/sprinter-mkdll
LIBMAN_DIR ?= ../../libman/libman
BUILD_DATE ?= $(shell date +%Y-%m-%d)
BUILD ?= build

PREFIX := $(BUILD)/WIN320.prefix.dll
FONT_WF32 := $(BUILD)/font.wf32
DLL := $(BUILD)/WIN320.DLL
RAW_DLL := $(BUILD)/WIN320.raw.dll
TEST_EXE := $(BUILD)/WIN320.EXE
RELEASE_DLL := WIN320.DLL
RELEASE_EXE := WIN320.EXE

.PHONY: all clean inspect verify raw test host-test z80-test release

all: $(DLL) $(TEST_EXE)

$(FONT_WF32): ../afnt320/font.bin ../afnt320/tools/font_to_accel.py
	mkdir -p $(BUILD)
	$(PYTHON) ../afnt320/tools/font_to_accel.py --wf32 $< $@

$(PREFIX): win320.asm stage1.inc win320.inc ../common/fontlayout.inc \
		../common/textcore320.inc
	mkdir -p $(BUILD)
	$(LIBMAN_MKDLL) build win320.asm --format l0 --target 1.2 \
		--assembler sjasmplus --compress --name "WIN320 GUI" \
		--version 0.1 --date $(BUILD_DATE) -o $@

$(DLL): $(PREFIX) $(FONT_WF32) tools/attach_payload.py
	$(PYTHON) tools/attach_payload.py $(PREFIX) $(FONT_WF32) $@

$(TEST_EXE): test.asm win320.inc $(DLL) $(LIBMAN_DIR)/libman.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --inc="$(LIBMAN_DIR)" --raw=$@ test.asm

test: $(TEST_EXE)

host-test: $(DLL)
	$(PYTHON) -m unittest discover -s tests -v

z80-test: $(FONT_WF32)
	bash tools/run_z80_tests.sh

inspect: $(DLL)
	$(LIBMAN_MKDLL) inspect $(DLL)

verify: $(DLL)
	$(LIBMAN_MKDLL) verify $(DLL) --target 1.2

raw: $(DLL)
	$(LIBMAN_MKDLL) decompress $(DLL) -o $(RAW_DLL)

release: all verify host-test z80-test
	cp $(DLL) $(RELEASE_DLL)
	cp $(TEST_EXE) $(RELEASE_EXE)

clean:
	rm -f $(PREFIX) $(FONT_WF32) $(DLL) $(RAW_DLL) $(TEST_EXE)
	rm -f $(BUILD)/z80-tests/*
