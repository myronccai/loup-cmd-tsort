#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), its standard error and its exit status with the expected
# ones. The expected output is GNU tsort 9.5's (LC_ALL=C), except for the
# help and version text and the BSD options -l and -q, which GNU lacks.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$1
FIX=tests/fixtures
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_err NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output, standard error and
# the exit status.
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    printf '%s' "$4" > "$TMP/want_err"
    shift 4
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want" "$TMP/out" && cmp -s "$TMP/want_err" "$TMP/err"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want" "$TMP/out" | sed 's/^/    stdout /' | head -10
        diff "$TMP/want_err" "$TMP/err" | sed 's/^/    stderr /' | head -10
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]: as check_err, with nothing
# expected on standard error.
check() {
    local name=$1 want_status=$2 want=$3
    shift 3
    check_err "$name" "$want_status" "$want" '' "$@"
}

TRY=$'Try \'tsort --help\' for more information.\n'

# Orders.
IN=<(printf 'a b\nb c\n')            check "chain"              0 $'a\nb\nc\n'
IN=<(printf 'c d\na b\nb c\n')       check "input order"        0 $'a\nb\nc\nd\n'
IN=<(printf 'b a\nc a\n')            check "free items sorted"  0 $'b\nc\na\n'
IN=<(printf 'Z a\n10 9\n')           check "byte order"         0 $'10\nZ\n9\na\n'
IN=<(printf 'a a\nb b\n')            check "self pairs"         0 $'a\nb\n'
IN=<(printf 'a b\na b\nb c\n')       check "repeated pair"      0 $'a\nb\nc\n'
IN=<(printf 'a\tb\r\n')              check "carriage return"    0 $'a\nb\r\n'
IN=<(printf 'a b c d')               check "no final newline"   0 $'a\nc\nb\nd\n'
IN=<(printf '')                      check "empty input"        0 ''
IN=<(printf 'é b\nb ü\n')            check "UTF-8 items"        0 $'é\nb\nü\n'
check "build graph" 0 $'config.h\nlexer.c\nlibm\nparse.y\neval.o\nmain.o\nlexer.o\nparse.c\nparse.o\ncalc\n' $FIX/build.txt
IN=$FIX/build.txt check "- is standard input" 0 $'config.h\nlexer.c\nlibm\nparse.y\neval.o\nmain.o\nlexer.o\nparse.c\nparse.o\ncalc\n' -

# Loops: reported on standard error, broken, and the order goes on.
IN=<(printf 'a b b a\n') check_err "two-item loop" 1 $'a\nb\n' $'tsort: -: input contains a loop:\ntsort: a\ntsort: b\n'
IN=<(printf 'x y\ny z\nz x\na b\n') check_err "loop behind free items" 1 $'a\nb\nx\ny\nz\n' \
    $'tsort: -: input contains a loop:\ntsort: x\ntsort: y\ntsort: z\n'
IN=<(printf 'a b\nb c\nc a\nc d\nd e\ne c\nb d\n') check_err "nested loops" 1 $'a\nb\nc\nd\ne\n' \
    $'tsort: -: input contains a loop:\ntsort: a\ntsort: b\ntsort: d\ntsort: e\ntsort: c\ntsort: -: input contains a loop:\ntsort: c\ntsort: d\ntsort: e\n'
check_err "loops in a file" 1 $'docs\napp\nnet\ntls\ntheme\nui\nwidgets\n' \
    $'tsort: tests/fixtures/loops.txt: input contains a loop:\ntsort: net\ntsort: tls\ntsort: tests/fixtures/loops.txt: input contains a loop:\ntsort: theme\ntsort: ui\ntsort: widgets\n' $FIX/loops.txt
"$BIN" $FIX/loops.txt > "$TMP/both" 2>&1 < /dev/null
if [ "$(tr '\n' '|' < "$TMP/both")" = 'docs|app|tsort: tests/fixtures/loops.txt: input contains a loop:|tsort: net|tsort: tls|net|tls|tsort: tests/fixtures/loops.txt: input contains a loop:|tsort: theme|tsort: ui|tsort: widgets|theme|ui|widgets|' ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: output and loop reports interleave as GNU's"
fi

# BSD options.
IN=<(printf 'a b\nb a\nb c\nc d\nd a\n') check_err "GNU reports the short loop first" 1 $'a\nb\nc\nd\n' \
    $'tsort: -: input contains a loop:\ntsort: a\ntsort: b\ntsort: -: input contains a loop:\ntsort: a\ntsort: b\ntsort: c\ntsort: d\n'
IN=<(printf 'a b\nb a\nb c\nc d\nd a\n') check_err "-l reports the longest loop" 1 $'a\nb\nc\nd\n' \
    $'tsort: -: input contains a loop:\ntsort: a\ntsort: b\ntsort: c\ntsort: d\ntsort: -: input contains a loop:\ntsort: a\ntsort: b\n' -l
check "-q keeps quiet" 1 $'docs\napp\nnet\ntls\ntheme\nui\nwidgets\n' -q $FIX/loops.txt

# Errors.
IN=<(printf 'a b c\n') check_err "odd count" 1 '' $'tsort: -: input contains an odd number of tokens\n'
check_err "missing file"    1 '' $'tsort: nosuch: No such file or directory\n'           nosuch
check_err "quoted name"     1 '' $'tsort: \'my file\': No such file or directory\n'     'my file'
check_err "directory"       1 '' $'tsort: tests: read error: Is a directory\n'          tests
check_err "invalid option"  1 '' "tsort: invalid option -- 'x'"$'\n'"$TRY"              -x
check_err "unknown option"  1 '' "tsort: unrecognized option '--bogus'"$'\n'"$TRY"      --bogus
check_err "extra operand"   1 '' "tsort: extra operand 'b'"$'\n'"$TRY"                  a b
check_err "-- then a name"  1 '' $'tsort: -x: No such file or directory\n'              -- -x

# Help and version.
check "version"             0 $'tsort (loup-cmd-tsort) 0.1.0\n'  --version
check "abbreviated --ver"   0 $'tsort (loup-cmd-tsort) 0.1.0\n'  --ver
"$BIN" a --help > "$TMP/help" 2>&1 < /dev/null
if [ $? -eq 0 ] && head -1 "$TMP/help" | grep -q '^Usage: tsort \[OPTION\] \[FILE\]$'; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: --help after an operand"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
