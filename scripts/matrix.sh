#!/usr/bin/env bash
#
# Generate the GitHub Actions matrix from images.txt.
#
#   scripts/matrix.sh                                every image
#   scripts/matrix.sh --ids "java-21 go-1.22"        only these images
#   scripts/matrix.sh --changed files.txt [--base SHA]
#                                                    only the images affected by the changed files
#
# Which images a changed file affects:
#   go/1.22/Dockerfile (or any file in   that image only
#     that image's own directory)
#   java/entrypoint.sh (a file shared    every image of that family
#     by a family)
#   images.txt                         only the rows that changed since --base (every image if --base is unknown)
#   tests/profiles/<profile>.sh        a sample of the images using that profile (first, middle, last)
#   tests/e2e/minecraft*, catalog.sh   a sample of the Java images
#   tests/e2e/steamcmd*                the Rust and Source images
#   tests/run.sh, tests/lib.sh,
#   scripts/*, the workflow            a smoke set: the first image of every test profile
#   anything else (README, ...)        nothing
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
BASE=""
IDS_ARG=""
MODE="all"

while [ $# -gt 0 ]; do
	case "$1" in
	--changed)
		CHANGED="$2"
		MODE="changed"
		shift
		;;
	--base)
		BASE="$2"
		shift
		;;
	--ids)
		IDS_ARG="$2"
		MODE="ids"
		shift
		;;
	*)
		echo "unknown option: $1" >&2
		exit 2
		;;
	esac
	shift
done

# --- Manifest helpers --------------------------------------------------------

all_ids() { awk -F'|' '!/^[[:space:]]*#/ && NF > 1 { print $1 }' "$MANIFEST"; }
field() { awk -F'|' -v id="$1" -v n="$2" '$1 == id { print $n; exit }' "$MANIFEST"; } # 2=context 6=profile 9=depends

ids_with_context() { awk -F'|' -v c="$1" '!/^[[:space:]]*#/ && $2 == c { print $1 }' "$MANIFEST"; }
ids_with_profile() { awk -F'|' -v p="$1" '!/^[[:space:]]*#/ && $6 == p { print $1 }' "$MANIFEST"; }

# A sample of the images using a test profile: the first, the middle one and the last.
sample_profile() {
	ids_with_profile "$1" | awk '{ a[NR] = $0 } END { if (NR) { print a[1]; print a[int((NR + 1) / 2)]; print a[NR] } }'
}

# Images affected by a changed file in a build directory.
#   - the file is an image Dockerfile                          -> that image
#   - the file is inside an image's own directory (go/1.22/..) -> that image
#   - the file sits directly in a shared context (java/x.sh)   -> every image of that context
ids_for_path() {
	awk -F'|' -v path="$1" '
		!/^[[:space:]]*#/ && NF > 1 {
			k++; id[k] = $1; ctx[k] = $2; df[k] = $3
			n = split($3, parts, "/"); dir = ""
			for (i = 1; i < n; i++) dir = dir (i > 1 ? "/" : "") parts[i]
			dd[k] = dir
		}
		END {
			for (i = 1; i <= k; i++) if (df[i] == path) { print id[i]; found = 1 }
			if (found) exit
			for (i = 1; i <= k; i++) {
				if (dd[i] != ctx[i] && index(path, dd[i] "/") == 1) print id[i]
				else if (index(path, ctx[i] "/") == 1) {
					rest = substr(path, length(ctx[i]) + 2)
					if (rest !~ /\//) print id[i]
				}
			}
		}' "$MANIFEST"
}

# The first image of every distinct test profile.
smoke_ids() { awk -F'|' '!/^[[:space:]]*#/ && NF > 1 && !seen[$6]++ { print $1 }' "$MANIFEST"; }

# Rows of images.txt that are new or different since $BASE (every id when the base is unknown).
changed_manifest_ids() {
	local old id row
	if [ -n "$BASE" ] && old="$(git -C "$ROOT" show "$BASE:images.txt" 2>/dev/null)"; then
		for id in $(all_ids); do
			row="$(awk -F'|' -v id="$id" '$1 == id' "$MANIFEST")"
			if [ "$(printf '%s\n' "$old" | awk -F'|' -v id="$id" '$1 == id')" != "$row" ]; then
				echo "$id"
			fi
		done
	else
		all_ids
	fi
}

# --- Selection ---------------------------------------------------------------

# Read ids on stdin and add them to SELECTED. Always called as `select_ids < <(command)` so it runs
# in the current shell (a function at the end of a pipeline would run in a subshell and lose them).
SELECTED=""
select_ids() {
	local line
	while IFS= read -r line; do
		[ -n "$line" ] && SELECTED="$SELECTED"$'\n'"$line"
	done
	return 0
}
is_selected() { printf '%s\n' "$SELECTED" | grep -qx "$1"; }

case "$MODE" in
all) select_ids < <(all_ids) ;;
ids)
	for id in $IDS_ARG; do
		[ -n "$(field "$id" 2)" ] || {
			echo "unknown image id: $id" >&2
			exit 2
		}
		SELECTED="$SELECTED"$'\n'"$id"
	done
	;;
changed)
	while IFS= read -r path; do
		[ -n "$path" ] || continue
		case "$path" in
		images.txt) select_ids < <(changed_manifest_ids) ;;
		tests/profiles/*.sh)
			p="${path#tests/profiles/}"
			select_ids < <(sample_profile "${p%.sh}")
			;;
		tests/e2e/steamcmd*) select_ids < <(ids_with_profile game-rust; ids_with_profile game-source) ;;
		tests/e2e/*) select_ids < <(sample_profile java) ;;
		tests/run.sh | tests/lib.sh | scripts/* | .github/workflows/images.yml) select_ids < <(smoke_ids) ;;
		*) select_ids < <(ids_for_path "$path") ;;
		esac
	done <"$CHANGED"
	;;
esac

# --- Legs: a root image plus its selected dependents -------------------------

entries=""
for root in $(all_ids); do
	[ -z "$(field "$root" 9)" ] || continue # dependents are attached to their root

	ids="$root"
	touched=0
	printf '%s\n' "$SELECTED" | grep -qx "$root" && touched=1
	for child in $(all_ids); do
		if [ "$(field "$child" 9)" = "$root" ]; then
			ids="$ids $child"
			printf '%s\n' "$SELECTED" | grep -qx "$child" && touched=1
		fi
	done

	[ "$touched" = "1" ] || continue
	name="${ids// /+}"
	[ -z "$entries" ] || entries="$entries,"
	entries="$entries{\"name\":\"$name\",\"ids\":\"$ids\"}"
done

printf '{"include":[%s]}\n' "$entries"
