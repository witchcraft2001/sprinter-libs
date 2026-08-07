#!/usr/bin/env bash
# Assemble and execute GFX640 at the real CPU addresses of WIN1..WIN3.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
test_src="$repo_root/tests/z80/t_init.asm"
build_dir="$repo_root/build/z80-tests"
dll="$repo_root/build/GFX640.DLL"
libman_dir="${LIBMAN_DIR:-$repo_root/../../libman/libman}"

addr_result=$((0xF000))
addr_done=$((0xF001))
addr_first=$((0xF002))
addr_fails=$((0xF003))
done_magic=165
ticks_limit=20000000

command -v sjasmplus >/dev/null 2>&1 || {
    echo "Error: sjasmplus not found in PATH" >&2
    exit 1
}

ticks="${TICKS:-/Users/dmitry/dev/zx/sprinter/z88dk/bin/z88dk-ticks}"
if [ ! -x "$ticks" ]; then
    ticks="z88dk-ticks"
    command -v "$ticks" >/dev/null 2>&1 || {
        echo "Error: z88dk-ticks not found; set TICKS to its path" >&2
        exit 1
    }
fi

mkdir -p "$build_dir"

byte_at() {
    dd if="$1" bs=1 skip="$2" count=1 2>/dev/null |
        od -An -tu1 | tr -d ' \n'
}

passed=0
failed=0

run_case() {
    local name="$1" origin="$2" stack="$3"
    local code_window="$4" stack_window="$5" vram_window="$6"
    local vram_port="$7" vram_base="$8"
    local bin="$build_dir/$name.bin"
    local dll_bin="$build_dir/$name-dll.bin"
    local dump="$build_dir/$name.out"
    local log="$build_dir/$name.asmlog"
    local lst="$build_dir/$name.lst"

    if ! sjasmplus --nologo --fullpath \
        -I "$repo_root" -I "$repo_root/tests/z80" -I "$libman_dir" \
        -DORIGIN_VALUE="$origin" -DSTACK_VALUE="$stack" \
        -DEXPECT_CODE_WIN="$code_window" \
        -DEXPECT_STACK_WIN="$stack_window" \
        -DEXPECT_VRAM_WIN="$vram_window" \
        -DEXPECT_VRAM_PORT="$vram_port" -DEXPECT_VRAM_BASE="$vram_base" \
        --lst="$lst" --raw="$bin" "$test_src" >"$log" 2>&1; then
        echo "  ASMFAIL  $name"
        sed 's/^/           /' "$log" | head -20
        failed=$((failed + 1))
        return
    fi

    run_binary "$name-source" "$bin"

    if ! "$repo_root/tools/prepare_runtime_image.py" \
        --dll "$dll" --template "$bin" --base "$origin" \
        --output "$dll_bin"; then
        echo "  FAIL     $name-dll (cannot decode/relocate release DLL)"
        failed=$((failed + 1))
        return
    fi
    run_binary "$name-dll" "$dll_bin"
}

run_binary() {
    local name="$1" bin="$2"
    local dump="$build_dir/$name.out"

    rm -f "$dump"
    "$ticks" -pc 0 -counter "$ticks_limit" -output "$dump" "$bin" \
        >/dev/null 2>&1 || true
    if [ ! -f "$dump" ]; then
        echo "  FAIL     $name (emulator produced no dump)"
        failed=$((failed + 1))
        return
    fi

    local done result first fails
    done="$(byte_at "$dump" "$addr_done")"
    result="$(byte_at "$dump" "$addr_result")"
    first="$(byte_at "$dump" "$addr_first")"
    fails="$(byte_at "$dump" "$addr_fails")"
    if [ "$done" != "$done_magic" ]; then
        echo "  FAIL     $name (did not complete: marker=$done)"
        failed=$((failed + 1))
    elif [ "$result" != 0 ]; then
        echo "  FAIL     $name ($fails assertion(s), first id $first)"
        failed=$((failed + 1))
    else
        echo "  PASS     $name"
        passed=$((passed + 1))
    fi
}

run_simple_test() {
    local name="$1"
    local src="$repo_root/tests/z80/$name.asm"
    local bin="$build_dir/$name.bin"
    local log="$build_dir/$name.asmlog"
    local lst="$build_dir/$name.lst"
    if ! sjasmplus --nologo --fullpath \
        -I "$repo_root" -I "$repo_root/tests/z80" -I "$libman_dir" \
        --lst="$lst" --raw="$bin" "$src" >"$log" 2>&1; then
        echo "  ASMFAIL  $name"
        sed 's/^/           /' "$log" | head -20
        failed=$((failed + 1))
        return
    fi
    run_binary "$name" "$bin"
}

echo "Running GFX640 Z80 harness..."
run_simple_test t_loader
run_simple_test t_libcall
run_case win1 16384 49136 1 2 3 226 49152
run_case win2 32768 32752 2 1 3 226 49152
run_case win3 49152 49136 3 2 1 162 16384

echo
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
