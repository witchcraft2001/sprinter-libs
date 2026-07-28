SHELL := /bin/sh

SJASMPLUS ?= sjasmplus
SDCC ?= sdcc
SDAR ?= sdar
LIBMAN_MKDLL ?= ../../libman/.venv/bin/sprinter-mkdll
LIBMAN_DIR ?= ../../libman/libman
BUILD_DATE ?= $(shell date +%Y-%m-%d)
BUILD ?= build
DLL := $(BUILD)/GFX320.DLL
RELEASE_DLL := GFX320.DLL
RAW_DLL := $(BUILD)/GFX320.raw.dll
TEST_EXE := $(BUILD)/GFX320.EXE
BENCH_EXE := $(BUILD)/GFXBENCH.EXE
RELEASE_EXE := GFX320.EXE
SDCC_REL := $(BUILD)/gfx320.rel
SDCC_LIB := $(BUILD)/gfx320.lib
RELEASE_SDCC_LIB := bindings/sdcc/gfx320.lib

.PHONY: all clean inspect verify raw test benchmark host-test z80-test bindings release

all: $(DLL) $(TEST_EXE) $(SDCC_LIB)

$(DLL): gfx320.asm common/accelerator.inc common/winmgr.inc common/palette.inc common/fade.inc
	mkdir -p $(BUILD)
	$(LIBMAN_MKDLL) build $< --format l0 --target 1.2 --assembler sjasmplus \
		--compress --name "GFX320 graphics" --version 1.1 --date $(BUILD_DATE) -o $@

$(TEST_EXE): test.asm gfx320.inc common/load_library.inc $(DLL) $(LIBMAN_DIR)/libman13.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --inc="$(LIBMAN_DIR)" --raw=$@ test.asm

test: $(TEST_EXE)

$(BENCH_EXE): test.asm gfx320.inc $(DLL) $(LIBMAN_DIR)/libman13.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --inc="$(LIBMAN_DIR)" -DGFX_BENCH=1 --raw=$@ test.asm

benchmark: $(BENCH_EXE)

host-test:
	python3 -m unittest discover -s tests -v

z80-test: $(DLL)
	tools/run_z80_tests.sh

$(SDCC_REL): bindings/sdcc/gfx320.c bindings/sdcc/gfx320.h
	mkdir -p $(BUILD)
	$(SDCC) -mz80 -Ibindings/sdcc -c $< -o $@

$(SDCC_LIB): $(SDCC_REL)
	$(SDAR) -rcsD $@ $<

bindings: $(SDCC_LIB)

inspect: $(DLL)
	$(LIBMAN_MKDLL) inspect $(DLL)

verify: $(DLL)
	$(LIBMAN_MKDLL) verify $(DLL) --target 1.2

release: all verify host-test z80-test
	cp $(DLL) $(RELEASE_DLL)
	cp $(TEST_EXE) $(RELEASE_EXE)
	cp $(SDCC_LIB) $(RELEASE_SDCC_LIB)

raw: $(DLL)
	$(LIBMAN_MKDLL) decompress $(DLL) -o $(RAW_DLL)

clean:
	rm -f $(DLL) $(RAW_DLL) $(TEST_EXE) $(BENCH_EXE) $(BUILD)/gfx320.*
