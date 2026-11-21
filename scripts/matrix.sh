#!/usr/bin/env bash
#
# Generate the GitHub Actions matrix from images.txt.
#
#   scripts/matrix.sh                         every image
#   scripts/matrix.sh --changed files.txt     only the touched images (one path per line)
#
# One matrix leg = one root image plus its dependents (e.g. java-25 then game-hytale),
# built and tested in order inside the same job: if the root fails, its dependents are
# neither tested nor published, while the other images are not blocked.
#
# Compatible with bash 3.2.

set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/images.txt"
CHANGED=""

while [ $# -gt 0 ]; do
	case "$1" in
	--changed)
		CHANGED="$2"
		shift
		;;
	*)
		echo "unknown option: $1" >&2
		exit 2
		;;
	esac
	shift
done

# A change in these paths invalidates everything.
GLOBAL_PATTERN='^(images\.txt|tests/|scripts/|\.github/workflows/images\.yml)'

all_changed=0
if [ -n "$CHANGED" ] && grep -qE "$GLOBAL_PATTERN" "$CHANGED"; then
	all_changed=1
fi

is_touched() { # id
	local context
	context="$(awk -F'|' -v id="$1" '$1 == id { print $2 }' "$MANIFEST")"
	[ -z "$CHANGED" ] && return 0
	[ "$all_changed" = "1" ] && return 0
	grep -qE "^${context}/" "$CHANGED"
}

entries=""
while IFS='|' read -r id _ _ _ _ _ _ _ depends _; do
	case "$id" in '' | \#*) continue ;; esac
	[ -z "$depends" ] || continue # dependents are attached to their root

	ids="$id"
	touched=0
	is_touched "$id" && touched=1
	while IFS='|' read -r child _ _ _ _ _ _ _ child_dep _; do
		case "$child" in '' | \#*) continue ;; esac
		if [ "$child_dep" = "$id" ]; then
			ids="$ids $child"
			is_touched "$child" && touched=1
		fi
	done <"$MANIFEST"

	[ "$touched" = "1" ] || continue
	name="${ids// /+}"
	[ -z "$entries" ] || entries="$entries,"
	entries="$entries{\"name\":\"$name\",\"ids\":\"$ids\"}"
done <"$MANIFEST"

printf '{"include":[%s]}\n' "$entries"
