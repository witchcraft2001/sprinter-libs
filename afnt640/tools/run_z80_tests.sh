#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
build_dir="$repo_root/build/z80-tests"
dll="$repo_root/build/AFNT640.DLL"
libman_dir="${LIBMAN_DIR:-$repo_root/../../libman/libman}"
ticks="${TICKS:-/Users/dmitry/dev/zx/sprinter/z88dk/bin/z88dk-ticks}"
if [ ! -x "$ticks" ]; then ticks="z88dk-ticks"; fi
command -v sjasmplus >/dev/null
command -v "$ticks" >/dev/null
mkdir -p "$build_dir"
cd "$repo_root"

byte_at() { dd if="$1" bs=1 skip="$2" count=1 2>/dev/null | od -An -tu1 | tr -d ' \n'; }
passed=0
failed=0
run_binary() {
	local name="$1" bin="$2" dump="$build_dir/$1.out"
	rm -f "$dump"
	"$ticks" -pc 0 -counter 20000000 -output "$dump" "$bin" >/dev/null 2>&1 || true
	if [ ! -f "$dump" ] || [ "$(byte_at "$dump" 65281)" != 165 ]; then
		echo "  FAIL     $name (did not complete)"; failed=$((failed+1)); return
	fi
	if [ "$(byte_at "$dump" 65280)" != 0 ]; then
		echo "  FAIL     $name ($(byte_at "$dump" 65283) assertion(s), first id $(byte_at "$dump" 65282))"; failed=$((failed+1)); return
	fi
	echo "  PASS     $name"; passed=$((passed+1))
}
run_case() {
	local name="$1" origin="$2" src="$repo_root/tests/z80/$1.asm"
	local bin="$build_dir/$name.bin" runtime="$build_dir/$name-dll.bin"
	sjasmplus --nologo --fullpath -I "$repo_root" -I "$repo_root/tests/z80" -I "$libman_dir" --raw="$bin" "$src" >/dev/null
	run_binary "$name-source" "$bin"
	"$repo_root/../gfx320/tools/prepare_runtime_image.py" --dll "$dll" --template "$bin" --base "$origin" --output "$runtime"
	run_binary "$name-dll" "$runtime"
}
echo "Running AFNT640 Z80 harness..."
run_case t_target 16384
run_case t_libcall 49152
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
