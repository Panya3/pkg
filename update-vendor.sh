#!/usr/bin/env bash
#
# update-vendor.sh — move a vendored member onto a newer upstream ref, locally.
#
# The pin of a submodule is a commit recorded in the superproject, so updating a
# member is a two-step decision: fetch the upstream ref, then record it. That is all
# this script does.
#
# What it deliberately does NOT do:
#   * it never builds. CI is this repository's build environment (docs/adr/0002), so
#     the proof that a new pin works comes from a run, not from this machine.
#   * it never commits and never pushes. You review the diff, commit signed, push.
#   * it never writes inside vendor/. The pin lives in the superproject.
#
# Usage:
#   ./update-vendor.sh                        report every member: its pin, the tag at
#                                             that pin, and the newest tags available
#   ./update-vendor.sh <member> <ref>         move <member> to <ref> (tag/branch/SHA)
#   ./update-vendor.sh --latest <member> ...  move each member to the newest tag its
#                                             upstream publishes (or its default
#                                             branch when it publishes no tags)
#   ./update-vendor.sh --dry-run <...>        say what would happen, change nothing
#   ./update-vendor.sh --help
#
# <member> may be spelled as a name (curl), a path (vendor/curl) or a suffix
# (neargye/magic_enum). Report mode reads the upstream remotes, so it needs the
# network; a move needs it too, to fetch the ref it is moving to.
#
# Conventions this script exists to keep (CLAUDE.md):
#   * shallow clones only (`--depth 1`)
#   * pin the latest release tag when upstream has one, the default branch otherwise —
#     and say why in the commit message when it is a branch rather than a tag
#   * a changed pin is a decision: state the reason, do not slip it into another commit
#
set -euo pipefail

usage() {
    sed -n '3,32p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
# Repository helpers
# ---------------------------------------------------------------------------

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "update-vendor: not inside a git work tree" >&2
    exit 1
fi
cd "$(git rev-parse --show-toplevel)"

members() {
    git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | sort
}

url_of() { git config -f .gitmodules --get "submodule.$1.url"; }
pin_of() { git ls-tree HEAD -- "$1" | awk '{print $3}'; }
short() { printf '%.10s' "$1"; }

# The tag spelling each upstream actually uses, read off their remotes rather than
# guessed: zlib and friends tag v1.2.3, curl tags curl-8_22_0, mbedtls tags
# mbedtls-4.2.0, and three projects publish no tags at all ('-': stb, yacppl,
# luajit — their pins are branch commits, which is why the pin question is asked per
# member instead of assumed).
tag_pattern() {
    case "$1" in
        vendor/curl) echo '^curl-[0-9]' ;;
        vendor/mbedtls) echo '^mbedtls-[0-9]' ;;
        vendor/stb | vendor/neargye/yacppl | vendor/luajit) echo '-' ;;
        *) echo '^v[0-9]' ;;
    esac
}

remote_tags() { git ls-remote --tags "$(url_of "$1")" 2>/dev/null || true; }

tag_names() {
    remote_tags "$1" | awk '{print $2}' | sed 's|refs/tags/||' | grep -v '\^{}$' || true
}

newest_tags() { # <path> [count]
    local pattern
    pattern="$(tag_pattern "$1")"
    [ "$pattern" = '-' ] && return 0
    tag_names "$1" | grep -E "$pattern" | sort -V | tail -n "${2:-3}"
}

tag_at_pin() {
    local sha
    sha="$(pin_of "$1")"
    remote_tags "$1" | awk -v s="$sha" '$1 == s {print $2}' |
        sed 's|refs/tags/||' | grep -v '\^{}$' | head -n1 || true
}

default_branch() {
    git ls-remote --symref "$(url_of "$1")" HEAD 2>/dev/null |
        awk '/^ref:/ {sub("refs/heads/", "", $2); print $2; exit}'
}

# <name> -> <path>, accepting a name, a full path or a suffix of one.
resolve_member() {
    local want="$1" path
    for path in $(members); do
        [ "$path" = "$want" ] && { echo "$path"; return 0; }
    done
    for path in $(members); do
        [ "$path" = "vendor/$want" ] && { echo "$path"; return 0; }
    done
    for path in $(members); do
        case "$path" in
            */"$want") echo "$path"; return 0 ;;
        esac
    done
    echo "update-vendor: no member matches '$want'" >&2
    echo "members: $(members | tr '\n' ' ')" >&2
    return 1
}

# A pin change has to be the only difference, or the diff stops being reviewable and
# `git add` would sweep unrelated work into the commit that records the pin.
require_clean() {
    if [ -n "$(git status --porcelain)" ]; then
        echo "update-vendor: the working tree is dirty — commit or stash first:" >&2
        git status --short >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

report() {
    printf '%-30s %-11s %-16s %s\n' MEMBER PIN 'TAG AT PIN' 'NEWEST UPSTREAM TAGS'
    local path tag newest
    for path in $(members); do
        tag="$(tag_at_pin "$path")"
        if [ "$(tag_pattern "$path")" = '-' ]; then
            newest="(no tags — default branch: $(default_branch "$path"))"
        else
            newest="$(newest_tags "$path" 3 | tr '\n' ' ')"
        fi
        printf '%-30s %-11s %-16s %s\n' "$path" "$(short "$(pin_of "$path")")" "${tag:--}" "$newest"
    done
}

# ---------------------------------------------------------------------------
# Move
# ---------------------------------------------------------------------------

move() { # <path> <ref>
    local path="$1" ref="$2" old new
    old="$(pin_of "$path")"
    if [ -z "$old" ]; then
        echo "update-vendor: '$path' is not a submodule of HEAD" >&2
        return 1
    fi

    # An uninitialised member is an empty directory, and `git -C <empty dir> fetch`
    # silently walks up to the superproject and fetches *its* origin instead — which
    # fails with a baffling "couldn't find remote ref master". Check for the
    # submodule's own .git first.
    if [ ! -e "$path/.git" ]; then
        echo "update-vendor: '$path' is not initialised yet — run:" >&2
        echo "  git submodule update --init --recursive --depth 1 -- $path" >&2
        return 1
    fi

    if ! git -C "$path" fetch --depth 1 --quiet origin "$ref"; then
        echo "update-vendor: cannot fetch '$ref' from $(url_of "$path")" >&2
        return 1
    fi
    new="$(git -C "$path" rev-parse 'FETCH_HEAD^{commit}')"

    if [ "$new" = "$old" ]; then
        echo "$path is already at $ref ($(short "$new")) — nothing to do"
        return 0
    fi

    echo "$path: $(short "$old") -> $(short "$new")   ($ref)"

    if [ "$dry_run" = yes ]; then
        echo "  dry run: the recorded pin and the checkout were left alone"
        return 0
    fi

    # Record the new commit in the superproject's index. The submodule's own checkout
    # follows, nested submodules included (vendor/mbedtls/framework).
    git update-index --cacheinfo "160000,$new,$path"
    if ! git submodule update --init --recursive --depth 1 -- "$path"; then
        echo "  warning: the checkout could not be synced; the recorded pin is still" >&2
        echo "  correct — sync it with:" >&2
        echo "    git submodule update --init --recursive --depth 1 -- $path" >&2
    fi

    case "$(tag_pattern "$path")" in
        '-') echo "  note: upstream publishes no tags, so this is a branch commit —" \
                  "say why in the commit message" ;;
    esac
    # The new pin is in the index already, and the checkout matches it, so a plain
    # `git diff` has nothing to show — the change to review is index against HEAD.
    echo "  next (the pin is staged — the commit below picks it up):"
    echo "    git diff HEAD --submodule=short -- $path"
    echo "    git commit -S -m \"build(vendor): move $(basename "$path") to $ref\""
    echo "    git push origin <branch>     # CI builds and proves the new pin (docs/adr/0002)"
}

# The newest tag the pattern allows; for a tagless member, the default branch.
latest_ref() { # <path>
    local path="$1" pattern newest branch
    pattern="$(tag_pattern "$path")"
    if [ "$pattern" = '-' ]; then
        branch="$(default_branch "$path")"
        if [ -z "$branch" ]; then
            echo "update-vendor: cannot read the default branch of $path" >&2
            return 1
        fi
        echo "$branch"
        return 0
    fi
    newest="$(newest_tags "$path" 1)"
    if [ -z "$newest" ]; then
        echo "update-vendor: no tag matching $pattern upstream for $path" >&2
        return 1
    fi
    echo "$newest"
}

# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------

dry_run=no
want_latest=no
targets=()

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help) usage; exit 0 ;;
        --dry-run) dry_run=yes; shift ;;
        --latest) want_latest=yes; shift ;;
        --report) want_latest=no; shift ;;
        -*) echo "update-vendor: unknown option '$1'" >&2; usage >&2; exit 2 ;;
        *) targets+=("$1"); shift ;;
    esac
done

if [ "$want_latest" = yes ]; then
    if [ ${#targets[@]} -eq 0 ]; then
        echo "update-vendor: --latest needs at least one member" >&2
        usage >&2
        exit 2
    fi
    require_clean
    # One member failing must not abandon the rest: a bulk update is exactly when a
    # single unreachable upstream is worth stepping over rather than stopping on.
    failures=0
    for name in "${targets[@]}"; do
        if ! path="$(resolve_member "$name")"; then
            failures=$((failures + 1))
            continue
        fi
        if ! ref="$(latest_ref "$path")"; then
            failures=$((failures + 1))
            continue
        fi
        move "$path" "$ref" || failures=$((failures + 1))
    done
    if [ "$failures" -ne 0 ]; then
        echo "update-vendor: $failures of ${#targets[@]} member(s) could not be updated" >&2
        exit 1
    fi
    exit 0
fi

case ${#targets[@]} in
    0) report ;;
    2)
        require_clean
        move "$(resolve_member "${targets[0]}")" "${targets[1]}"
        ;;
    *)
        echo "update-vendor: expected a member and a ref" >&2
        usage >&2
        exit 2
        ;;
esac
