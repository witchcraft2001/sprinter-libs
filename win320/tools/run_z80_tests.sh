#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
build_dir="$repo_root/build/z80-tests"

mkdir -p "$build_dir"

ticks="${TICKS:-/Users/dmitry/dev/zx/sprinter/z88dk/bin/z88dk-ticks}"
if [ ! -x "$ticks" ]; then
    ticks="z88dk-ticks"
fi

command -v sjasmplus >/dev/null 2>&1
command -v "$ticks" >/dev/null 2>&1

byte_at() {
    dd if="$1" bs=1 skip="$2" count=1 2>/dev/null |
        od -An -tu1 | tr -d ' \n'
}

cd "$repo_root"
for stage in stage0 stage1; do
    src="$repo_root/tests/z80/t_${stage}.asm"
    bin="$build_dir/t_${stage}.bin"
    dump="$build_dir/t_${stage}.out"
    log="$build_dir/t_${stage}.asmlog"
    lst="$build_dir/t_${stage}.lst"

    sjasmplus --nologo --fullpath -I "$repo_root" -I "$repo_root/tests/z80" \
        --lst="$lst" --raw="$bin" "$src" >"$log" 2>&1

    rm -f "$dump"
    "$ticks" -pc 0 -counter 60000000 -output "$dump" "$bin" >/dev/null 2>&1 || true

    done_marker="$(byte_at "$dump" $((0xe001)))"
    result="$(byte_at "$dump" $((0xe000)))"
    first="$(byte_at "$dump" $((0xe002)))"
    fails="$(byte_at "$dump" $((0xe003)))"

    if [ "$done_marker" != 165 ]; then
        echo "FAIL: WIN320 Z80 $stage harness did not complete (marker=$done_marker)"
        exit 1
    fi
    if [ "$result" != 0 ]; then
        echo "FAIL: WIN320 Z80 $stage harness: $fails assertion(s), first id $first"
        exit 1
    fi
    echo "PASS: WIN320 Z80 $stage harness"
done
