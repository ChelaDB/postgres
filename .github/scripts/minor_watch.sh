#!/usr/bin/env bash
# Watches postgres/postgres for new minor releases (minor-watch.yml, daily).
#
# For each major in 14-17 that is not listed in FROZEN, compares the version in
# configure.ac's AC_INIT on REL_<major>_STABLE_cheladb with the newest
# REL_<major>_<n> tag on postgres/postgres (beta and rc tags are ignored). When
# the tag is newer it opens the issue "Merge PostgreSQL <major>.<n>" (label
# `security`), listing every missing minor, unless an issue with that exact
# title exists, open or closed.
#
# Environment:
#   GITHUB_REPOSITORY  this repo (default ChelaDB/postgres); GH_TOKEN for gh
#   UPSTREAM           repo holding the release tags (default postgres/postgres)
#   MAJORS             majors to watch (default "14 15 16 17")
#   FROZEN_FILE        majors to skip, one per line, `#` comments and blank
#                      lines ignored (default: FROZEN at the repo root)
#   DRY_RUN=1          print what would be opened; create no label or issue
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="${GITHUB_REPOSITORY:-ChelaDB/postgres}"
upstream="${UPSTREAM:-postgres/postgres}"
majors="${MAJORS:-14 15 16 17}"
frozen_file="${FROZEN_FILE:-$here/../../FROZEN}"
dry_run="${DRY_RUN:-0}"

is_frozen() {
    [[ -f "$frozen_file" ]] && sed -e 's/#.*//' -e 's/[[:space:]]//g' "$frozen_file" | grep -qx "$1"
}

# fork_minor <major>: the minor of AC_INIT's version on the fork's branch.
fork_minor() {
    local major="$1" line
    line="$(gh api -H 'Accept: application/vnd.github.raw' \
        "repos/${repo}/contents/configure.ac?ref=REL_${major}_STABLE_cheladb" | grep -m1 '^AC_INIT')"
    if [[ "$line" =~ \[${major}\.([0-9]+)\] ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "minor_watch: cannot read a ${major}.<n> version from AC_INIT: $line" >&2
        return 1
    fi
}

# upstream_minors <major>: every released minor n (REL_<major>_<n>, numeric
# only, so betas and rcs drop out), ascending.
upstream_minors() {
    local major="$1"
    gh api "repos/${upstream}/git/matching-refs/tags/REL_${major}_" --paginate --jq '.[].ref' |
        sed -n "s|^refs/tags/REL_${major}_\([0-9][0-9]*\)\$|\1|p" | sort -n
}

# ensure_label: creates `security` when the repo lacks it.
ensure_label() {
    gh label create security -R "$repo" --description "Security-relevant upstream release" --color d93f0b 2>/dev/null || true
}

main() {
    local existing major have n newest missing list title body
    existing="$(gh issue list -R "$repo" --state all --limit 1000 --json title --jq '.[].title')"
    local label_ready=0

    for major in $majors; do
        if is_frozen "$major"; then
            echo "$major: frozen, skipped"
            continue
        fi
        have="$(fork_minor "$major")" || exit 1
        missing=()
        while read -r n; do
            if ((n > have)); then missing+=("$n"); fi
        done < <(upstream_minors "$major")
        if ((${#missing[@]} == 0)); then
            echo "$major: ${major}.${have} is current"
            continue
        fi
        newest="${missing[-1]}"
        title="Merge PostgreSQL ${major}.${newest}"
        if grep -qxF "$title" <<<"$existing"; then
            echo "$major: \"$title\" already exists, skipped"
            continue
        fi
        list=""
        for n in "${missing[@]}"; do list+="${list:+, }${major}.${n}"; done
        body="REL_${major}_STABLE_cheladb is at ${major}.${have}; postgres/postgres has released ${major}.${newest}. Missing minors: ${list}. Merge the upstream tags REL_${major}_$((have + 1)) through REL_${major}_${newest} into REL_${major}_STABLE_cheladb, in order. Release notes: https://www.postgresql.org/docs/release/${major}.${newest}/"
        if [[ "$dry_run" == "1" ]]; then
            echo "DRY RUN: would open \"$title\" (label security): $body"
            continue
        fi
        if ((label_ready == 0)); then
            ensure_label
            label_ready=1
        fi
        gh issue create -R "$repo" --title "$title" --label security --body "$body"
        echo "$major: opened \"$title\""
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
