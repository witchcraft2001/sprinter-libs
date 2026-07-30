#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
build_dir="$repo_root/build/z80-tests"
src="$repo_root/tests/z80/t_stage0.asm"
bin="$build_dir/t_stage0.bin"
dump="$build_dir/t_stage0.out"
log="$build_dir/t_stage0.asmlog"
lst="$build_dir/t_stage0.lst"

mkdir -p "$build_dir"

ticks="${TICKS:-/Users/dmitry/dev/zx/sprinter/z88dk/bin/z88dk-ticks}"
if [ ! -x "$ticks" ]; then
    ticks="z88dk-ticks"
fi

command -v sjasmplus >/dev/null 2>&1
command -v "$ticks" >/dev/null 2>&1

cd "$repo_root"
sjasmplus --nologo --fullpath -I "$repo_root" -I "$repo_root/tests/z80" \
    --lst="$lst" --raw="$bin" "$src" >"$log" 2>&1

rm -f "$dump"
"$ticks" -pc 0 -counter 30000000 -output "$dump" "$bin" >/dev/null 2>&1 || true

byte_at() {
    dd if="$dump" bs=1 skip="$1" count=1 2>/dev/null |
        od -An -tu1 | tr -d ' \n'
}

done_marker="$(byte_at $((0xe001)))"
result="$(byte_at $((0xe000)))"
first="$(byte_at $((0xe002)))"
fails="$(byte_at $((0xe003)))"

if [ "$done_marker" != 165 ]; then
    echo "FAIL: WIN320 Z80 harness did not complete (marker=$done_marker)"
    exit 1
fi
if [ "$result" != 0 ]; then
    echo "FAIL: WIN320 Z80 harness: $fails assertion(s), first id $first"
    exit 1
fi
echo "PASS: WIN320 Z80 stage-0 harness"
