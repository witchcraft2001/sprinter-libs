SHELL := /bin/sh

SJASMPLUS ?= sjasmplus
PYTHON ?= python3
LIBMAN_MKDLL ?= ../../libman/.venv/bin/sprinter-mkdll
LIBMAN_DIR ?= ../../libman/libman
BUILD_DATE ?= $(shell date +%Y-%m-%d)
BUILD ?= build

PREFIX := $(BUILD)/WIN320.prefix.dll
FONT_WF32 := $(BUILD)/font.wf32
STAGE5_OVERLAY := $(BUILD)/stage5.overlay
DLL := $(BUILD)/WIN320.DLL
RAW_DLL := $(BUILD)/WIN320.raw.dll
TEST_EXE := $(BUILD)/WIN320.EXE
EXAMPLE_ICONS := examples/icons.wip
RELEASE_DLL := WIN320.DLL
RELEASE_EXE := WIN320.EXE
RELEASE_ICONS := ICONS.WIP

.PHONY: all clean inspect verify raw test host-test z80-test release

all: $(DLL) $(TEST_EXE)

$(FONT_WF32): ../afnt320/font.bin ../afnt320/tools/font_to_accel.py
	mkdir -p $(BUILD)
	$(PYTHON) ../afnt320/tools/font_to_accel.py --wf32 $< $@

$(PREFIX): win320.asm stage1.inc stage2.inc stage3.inc stage4.inc stage5_stub.inc win320.inc ../common/fontlayout.inc \
		../common/textcore320.inc
	mkdir -p $(BUILD)
	$(LIBMAN_MKDLL) build win320.asm --format l0 --target 1.2 \
		--assembler sjasmplus --compress --name "WIN320 GUI" \
		--version 0.1 --date $(BUILD_DATE) -o $@

$(STAGE5_OVERLAY): $(PREFIX) stage5_overlay.asm stage5.inc win320.inc tools/build_stage5_overlay.py
	$(SJASMPLUS) --sym=$(BUILD)/win320.sym --raw=$(BUILD)/win320.symbols.bin win320.asm
	$(PYTHON) tools/build_stage5_overlay.py --root . --symbols $(BUILD)/win320.sym \
		--imports $(BUILD)/stage5_symbols.inc --output $@

$(DLL): $(PREFIX) $(FONT_WF32) $(STAGE5_OVERLAY) tools/attach_payload.py
	$(PYTHON) tools/attach_payload.py $(PREFIX) $(FONT_WF32) $@ $(STAGE5_OVERLAY)

$(EXAMPLE_ICONS): examples/icons_wip.asm
	$(SJASMPLUS) --nologo --raw=$@ $<

$(TEST_EXE): test.asm win320.inc $(DLL) $(EXAMPLE_ICONS) $(LIBMAN_DIR)/libman.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --inc="$(LIBMAN_DIR)" --raw=$@ test.asm

test: $(TEST_EXE)

host-test: $(DLL) $(EXAMPLE_ICONS)
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
	cp $(EXAMPLE_ICONS) $(RELEASE_ICONS)

clean:
	rm -f $(PREFIX) $(FONT_WF32) $(DLL) $(RAW_DLL) $(TEST_EXE)
	rm -f $(STAGE5_OVERLAY) $(BUILD)/stage5.*.bin $(BUILD)/stage5_symbols.inc
	rm -f $(BUILD)/win320.sym $(BUILD)/win320.symbols.bin
	rm -f $(BUILD)/z80-tests/*
