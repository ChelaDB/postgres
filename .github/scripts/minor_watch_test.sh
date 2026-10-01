#!/usr/bin/env bash
# Self-test for minor_watch.sh (plain bash, no network): `gh` is a stub on PATH
# that answers from fixture files in $FIX and records the write calls
# (`label create`, `issue create`) in $FIX/writes. Run from anywhere:
#   .github/scripts/minor_watch_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/minor_watch.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Fixtures in $FIX: tags_<major> (one refs/tags/... per line), ac_<major> (the
# AC_INIT line of that major's configure.ac), issues (existing titles, one per
# line, open or closed). Any other call is a write and is recorded.
args="$*"
if [[ "$1" == "api" ]]; then
    if [[ "$args" =~ matching-refs/tags/REL_([0-9]+)_ ]]; then
        [[ -e "$FIX/tags_fail" ]] && exit 1
        cat "$FIX/tags_${BASH_REMATCH[1]}"
    elif [[ "$args" =~ contents/configure.ac\?ref=REL_([0-9]+)_STABLE_cheladb ]]; then
        cat "$FIX/ac_${BASH_REMATCH[1]}"
    else
        echo "stub gh: unexpected api call: $args" >&2
        exit 1
    fi
elif [[ "$1 $2" == "issue list" ]]; then
    cat "$FIX/issues"
else
    printf '%s\n' "$args" >>"$FIX/writes"
fi
STUB
chmod +x "$tmp/bin/gh"

failures=0
n=0

# tags <major> <minor>...: a tag fixture with beta/rc noise around the minors.
tags() {
    local major="$1"
    shift
    {
        echo "refs/tags/REL_${major}_BETA1"
        echo "refs/tags/REL_${major}_RC1"
        local m
        for m in "$@"; do echo "refs/tags/REL_${major}_${m}"; done
        echo "refs/tags/REL_${major}_RC9"
    }
}

# setup: fresh fixtures. 17: 17.5 vs newest 17.11; 16, 15 and 14 are current.
setup() {
    n=$((n + 1))
    FIX="$tmp/fix$n"
    export FIX
    mkdir "$FIX"
    tags 17 0 1 2 3 4 5 6 7 8 9 10 11 >"$FIX/tags_17"
    tags 16 0 1 9 >"$FIX/tags_16"
    tags 15 12 13 >"$FIX/tags_15"
    tags 14 17 18 >"$FIX/tags_14"
    echo "AC_INIT([PostgreSQL], [17.5], [pgsql-bugs@lists.postgresql.org], [], [https://www.postgresql.org/])" >"$FIX/ac_17"
    echo "AC_INIT([PostgreSQL], [16.9], [pgsql-bugs@lists.postgresql.org], [], [https://www.postgresql.org/])" >"$FIX/ac_16"
    echo "AC_INIT([PostgreSQL], [15.13], [pgsql-bugs@lists.postgresql.org], [], [https://www.postgresql.org/])" >"$FIX/ac_15"
    echo "AC_INIT([PostgreSQL], [14.18], [pgsql-bugs@lists.postgresql.org], [], [https://www.postgresql.org/])" >"$FIX/ac_14"
    : >"$FIX/issues"
    : >"$FIX/writes"
    : >"$tmp/FROZEN"
}

# run: runs the script against the fixtures; stdout in $tmp/out.
run() {
    PATH="$tmp/bin:$PATH" FROZEN_FILE="$tmp/FROZEN" "$script" >"$tmp/out" 2>"$tmp/err" ||
        echo "script exited non-zero: $(cat "$tmp/err")"
}

# ok_if <name> <command...>: the command must succeed.
ok_if() {
    local name="$1"
    shift
    if "$@"; then
        echo "ok: $name"
    else
        echo "FAIL: $name"
        failures=$((failures + 1))
    fi
}

first_write_is_label() { head -n1 "$FIX/writes" | grep -q "^label create security"; }
creates() { grep -c '^issue create' "$FIX/writes"; }

# 1. 17.5 vs 17.11: one title, listing 17.6-17.11.
setup
run
ok_if "17.5 vs 17.11: opens exactly one issue" test "$(creates)" = 1
ok_if "17.5 vs 17.11: title is Merge PostgreSQL 17.11" grep -q -- '--title Merge PostgreSQL 17.11 ' "$FIX/writes"
ok_if "17.5 vs 17.11: label security" grep -q -- '--label security' "$FIX/writes"
ok_if "17.5 vs 17.11: body lists 17.6 through 17.11" \
    grep -q '17\.6, 17\.7, 17\.8, 17\.9, 17\.10, 17\.11' "$FIX/writes"
ok_if "17.5 vs 17.11: the list starts at 17.6 and has no beta/rc tags" \
    bash -c "grep -q 'Missing minors: 17\\.6,' \"\$1\" && ! grep -Eq 'BETA|RC' \"\$1\"" _ "$FIX/writes"
ok_if "the security label is created before the issue" first_write_is_label

# 2. Equal versions: nothing.
setup
echo "refs/tags/REL_17_5" >"$FIX/tags_17"
run
ok_if "equal versions: no writes" test ! -s "$FIX/writes"

# 3. A major in FROZEN is skipped.
setup
printf '# comment line\n\n17\n' >"$tmp/FROZEN"
run
ok_if "FROZEN major: no writes" test ! -s "$FIX/writes"

# 4. An existing title (open or closed) is not duplicated; `issue list` can't
# tell open from closed here, which is the point: both are listed.
setup
echo "Merge PostgreSQL 17.11" >"$FIX/issues"
run
ok_if "existing title: no writes" test ! -s "$FIX/writes"

# 4b. A different existing title does not suppress the issue.
setup
echo "Merge PostgreSQL 17.10" >"$FIX/issues"
run
ok_if "other title: still opens 17.11" test "$(creates)" = 1

# 5. Several majors behind: one issue each, with their own minors.
setup
echo "AC_INIT([PostgreSQL], [16.7], [x], [], [y])" >"$FIX/ac_16"
tags 16 7 8 9 >"$FIX/tags_16"
run
ok_if "two majors behind: two issues" test "$(creates)" = 2
ok_if "16: title and minors" grep -q -- '--title Merge PostgreSQL 16.9 .*16\.8, 16\.9' "$FIX/writes"

# 6. Minors numbered with two digits sort numerically (17.9 < 17.10).
setup
echo "AC_INIT([PostgreSQL], [17.9], [x], [], [y])" >"$FIX/ac_17"
run
ok_if "17.9 vs 17.11: lists only 17.10, 17.11" grep -q '17\.10, 17\.11' "$FIX/writes"

# 7. DRY_RUN=1 prints what it would open and writes nothing.
setup
DRY_RUN=1 run
ok_if "DRY_RUN: no writes" test ! -s "$FIX/writes"
ok_if "DRY_RUN: prints the title" grep -q 'Merge PostgreSQL 17.11' "$tmp/out"
ok_if "DRY_RUN: prints the minors" grep -q '17.6, 17.7, 17.8, 17.9, 17.10, 17.11' "$tmp/out"

# 8. A failing or empty tag listing is an error, not "current".
setup
touch "$FIX/tags_fail"
PATH="$tmp/bin:$PATH" FROZEN_FILE="$tmp/FROZEN" "$script" >"$tmp/out" 2>"$tmp/err"
rc=$?
ok_if "failing tag listing: exits non-zero" test "$rc" -ne 0
ok_if "failing tag listing: no writes" test ! -s "$FIX/writes"
ok_if "failing tag listing: never says current" bash -c "! grep -q current \"\$1\"" _ "$tmp/out"

setup
: >"$FIX/tags_17"
PATH="$tmp/bin:$PATH" FROZEN_FILE="$tmp/FROZEN" "$script" >"$tmp/out" 2>"$tmp/err"
rc=$?
ok_if "empty tag listing: exits non-zero" test "$rc" -ne 0
ok_if "empty tag listing: no writes" test ! -s "$FIX/writes"

if ((failures > 0)); then
    echo "$failures failure(s)"
    exit 1
fi
echo "all passed"
