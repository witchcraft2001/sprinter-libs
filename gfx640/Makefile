SHELL := /bin/sh

SJASMPLUS ?= sjasmplus
SDCC ?= sdcc
SDAR ?= sdar
LIBMAN_MKDLL ?= ../../libman/.venv/bin/sprinter-mkdll
LIBMAN_DIR ?= ../../libman/libman
BUILD_DATE ?= $(shell date +%Y-%m-%d)
BUILD ?= build
DLL := $(BUILD)/GFX640.DLL
RELEASE_DLL := GFX640.DLL
RAW_DLL := $(BUILD)/GFX640.raw.dll
TEST_EXE := $(BUILD)/GFX640.EXE
BENCH_EXE := $(BUILD)/GFXBENCH.EXE
RELEASE_EXE := GFX640.EXE
SDCC_REL := $(BUILD)/gfx640.rel
SDCC_LIB := $(BUILD)/gfx640.lib
RELEASE_SDCC_LIB := bindings/sdcc/gfx640.lib

.PHONY: all clean inspect verify raw test benchmark host-test z80-test bindings release size-check

all: $(DLL) $(TEST_EXE) $(SDCC_LIB)

$(DLL): gfx640.asm ../common/accelerator.inc ../common/winmgr.inc ../common/palette.inc ../common/fade.inc
	mkdir -p $(BUILD)
	$(LIBMAN_MKDLL) build $< --format l0 --target 1.2 --assembler sjasmplus \
		--compress --name "GFX640 graphics" --version 1.0 --date $(BUILD_DATE) -o $@

$(TEST_EXE): test.asm gfx640.inc ../common/load_library.inc $(DLL) $(LIBMAN_DIR)/libman13.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --inc="$(LIBMAN_DIR)" --raw=$@ test.asm

test: $(TEST_EXE)

$(BENCH_EXE): test.asm gfx640.inc $(DLL) $(LIBMAN_DIR)/libman13.asm
	mkdir -p $(BUILD)
	$(SJASMPLUS) --inc="$(LIBMAN_DIR)" -DGFX_BENCH=1 --raw=$@ test.asm

benchmark: $(BENCH_EXE)

host-test:
	python3 -m unittest discover -s tests -v

z80-test: $(DLL)
	tools/run_z80_tests.sh

$(SDCC_REL): bindings/sdcc/gfx640.c bindings/sdcc/gfx640.h
	mkdir -p $(BUILD)
	$(SDCC) -mz80 -Ibindings/sdcc -c $< -o $@

$(SDCC_LIB): $(SDCC_REL)
	$(SDAR) -rcsD $@ $<

bindings: $(SDCC_LIB)

inspect: $(DLL)
	$(LIBMAN_MKDLL) inspect $(DLL)

verify: $(DLL) size-check
	$(LIBMAN_MKDLL) verify $(DLL) --target 1.2

size-check: $(DLL)
	@test `wc -c < $(DLL)` -le 16384 || { echo "GFX640 L0 exceeds one 16-KiB window"; exit 1; }

release: all verify host-test z80-test
	cp $(DLL) $(RELEASE_DLL)
	cp $(TEST_EXE) $(RELEASE_EXE)
	cp $(SDCC_LIB) $(RELEASE_SDCC_LIB)

raw: $(DLL)
	$(LIBMAN_MKDLL) decompress $(DLL) -o $(RAW_DLL)

clean:
	rm -f $(DLL) $(RAW_DLL) $(TEST_EXE) $(BENCH_EXE) $(BUILD)/gfx640.*
