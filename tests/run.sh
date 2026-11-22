#!/usr/bin/env bash
#
# Build and test the depot images (images.txt), locally or in CI.
#
#   tests/run.sh                         every image, host platform
#   tests/run.sh java-21 nodejs-20       only these ids (dependencies included)
#   tests/run.sh --all-platforms         test every declared platform (QEMU if needed)
#   tests/run.sh --platform linux/amd64  force a platform
#   tests/run.sh --no-build java-21      reuse already built local images
#   tests/run.sh --keep                  keep the local test images
#   tests/run.sh --publish               after the tests pass, push the multi-arch image (CI)
#   tests/run.sh --jobs 4                test up to 4 independent images at the same time
#   tests/run.sh --list                  list the ids
#
# An image is NEVER published when one of its tests fails (nor are its dependents).
#
# Environment: DEPOT_TEST_NETWORK=0 disables the tests that need internet access.
#              DEPOT_TAG_SUFFIX=20261121 adds an immutable <tag>-<suffix> tag with --publish.
#              DEPOT_CACHE=gha uses the GitHub Actions build cache (CI only).
#              DEPOT_TEST_E2E=1 adds the end-to-end tests (real Minecraft server, steamcmd).
#
# Compatible with bash 3.2 (macOS): no associative arrays.

set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"

ALL_PLATFORMS=0
FORCE_PLATFORM=""
NO_BUILD=0
KEEP=0
PUBLISH=0
LIST=0
JOBS=1
RESULTS_FILE=""
REQUESTED=()

while [ $# -gt 0 ]; do
	case "$1" in
	--all-platforms) ALL_PLATFORMS=1 ;;
	--platform)
		FORCE_PLATFORM="$2"
		shift
		;;
	--no-build) NO_BUILD=1 ;;
	--keep) KEEP=1 ;;
	--publish) PUBLISH=1 ;;
	--list) LIST=1 ;;
	--jobs)
		JOBS="$2"
		shift
		;;
	--results)
		RESULTS_FILE="$2"
		shift
		;;
	-h | --help)
		sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	-*)
		echo "unknown option: $1" >&2
		exit 2
		;;
	*) REQUESTED+=("$1") ;;
	esac
	shift
done

# --- Manifest ----------------------------------------------------------------

MANIFEST="$ROOT/images.txt"

# manifest_field <id> <n>: 2=context 3=Dockerfile 4=image 5=platforms 6=profile 7=expect 8=build-args 9=depends on 10=max size (MB)
manifest_field() {
	awk -F'|' -v id="$1" -v n="$2" '$1 == id { print $n; exit }' "$MANIFEST"
}
m_context() { manifest_field "$1" 2; }
m_dockerfile() { manifest_field "$1" 3; }
m_image() { manifest_field "$1" 4; }
m_platforms() { manifest_field "$1" 5; }
m_profile() { manifest_field "$1" 6; }
m_expect() { manifest_field "$1" 7; }
m_buildargs() { manifest_field "$1" 8; }
m_depends() { manifest_field "$1" 9; }
m_maxsize() { manifest_field "$1" 10; }

IDS=()
while IFS= read -r line; do IDS+=("$line"); done < <(awk -F'|' '!/^[[:space:]]*#/ && NF > 1 { print $1 }' "$MANIFEST")

set_result() { printf -v "RESULT_${1//[^a-zA-Z0-9]/_}" '%s' "$2"; }
get_result() {
	local v="RESULT_${1//[^a-zA-Z0-9]/_}"
	printf '%s' "${!v:-}"
}

if [ "$LIST" = "1" ]; then
	printf '%s\n' "${IDS[@]}"
	exit 0
fi

# --- Selection (with dependencies) -------------------------------------------

SELECTED=()
add_with_deps() {
	local id="$1" dep s
	[ -n "$(m_image "$id")" ] || {
		echo "unknown id: $id (see --list)" >&2
		exit 2
	}
	dep="$(m_depends "$id")"
	[ -n "$dep" ] && add_with_deps "$dep"
	for s in ${SELECTED[@]+"${SELECTED[@]}"}; do [ "$s" = "$id" ] && return 0; done
	SELECTED+=("$id")
}

if [ ${#REQUESTED[@]} -eq 0 ]; then
	for id in "${IDS[@]}"; do add_with_deps "$id"; done
else
	for id in "${REQUESTED[@]}"; do add_with_deps "$id"; done
fi

# --- Helpers -----------------------------------------------------------------


host_platform() {
	case "$(docker version --format '{{.Server.Arch}}' 2>/dev/null)" in
	arm64 | aarch64) echo linux/arm64 ;;
	*) echo linux/amd64 ;;
	esac
}

local_tag() { # id platform
	echo "depot-test/$1:${2//\//-}"
}

platforms_to_test() { # id
	local id="$1" declared host
	declared="$(m_platforms "$id")"
	if [ -n "$FORCE_PLATFORM" ]; then
		echo "$FORCE_PLATFORM"
	elif [ "$ALL_PLATFORMS" = "1" ]; then
		echo "${declared//,/ }"
	else
		host="$(host_platform)"
		case ",$declared," in
		*",$host,"*) echo "$host" ;;
		*) echo "${declared%%,*}" ;; # e.g. amd64 only -> emulation
		esac
	fi
}

# Print one "--build-arg KEY=VALUE" per line pair, replacing {id} with a base image reference.
# $3 = "local" (tag built on this machine for the platform) or "public" (published tag).
resolve_buildargs() { # id platform mode
	local id="$1" platform="$2" mode="$3" pair key value ref buildargs
	buildargs="$(m_buildargs "$id")"
	[ -n "$buildargs" ] || return 0
	IFS=',' read -ra pairs <<<"$buildargs"
	for pair in "${pairs[@]}"; do
		key="${pair%%=*}"
		value="${pair#*=}"
		while [[ "$value" =~ \{([a-z0-9._-]+)\} ]]; do
			ref="${BASH_REMATCH[1]}"
			if [ "$mode" = "local" ]; then
				value="${value//\{$ref\}/$(local_tag "$ref" "$platform")}"
			else
				value="${value//\{$ref\}/$(m_image "$ref")}"
			fi
		done
		printf -- '--build-arg\n%s=%s\n' "$key" "$value"
	done
}

# Build cache options (CI only): one cache scope per image and platform.
cache_args() { # id platform [write]
	[ "${DEPOT_CACHE:-}" = "gha" ] || return 0
	printf -- '--cache-from\ntype=gha,scope=%s-%s\n' "$1" "${2//\//-}"
	[ "${3:-}" = "write" ] && printf -- '--cache-to\ntype=gha,mode=max,scope=%s-%s\n' "$1" "${2//\//-}"
	return 0
}

# Name of a buildx builder that uses the "docker" driver (it can see images of the local daemon).
docker_driver_builder() {
	docker buildx ls 2>/dev/null | awk '$1 !~ /^\\_/ && $2 == "docker" { n = $1; gsub(/\*/, "", n); print n; exit }'
}

# Run a build command, retrying when QEMU crashes (it segfaults now and then on emulated platforms).
with_qemu_retry() { # command...
	local attempt out rc
	for attempt in 1 2 3; do
		out="$("$@" 2>&1)"
		rc=$?
		if [ "$rc" -eq 0 ]; then
			printf '%s\n' "$out"
			return 0
		fi
		if ! printf '%s' "$out" | grep -q 'qemu: uncaught target signal'; then
			break
		fi
		printf '  (qemu crashed, retrying %d/3)\n' "$attempt" >&2
	done
	printf '%s\n' "$out"
	return "$rc"
}

build_local() { # id platform
	local id="$1" platform="$2" tag dep line builder=""
	local args=() pull=(--pull)
	tag="$(local_tag "$id" "$platform")"

	# A dependency is a local image: it must exist for this platform, must not be pulled, and the
	# build must use a builder that can see the local daemon (the docker-container driver cannot).
	dep="$(m_depends "$id")"
	if [ -n "$dep" ]; then
		pull=()
		builder="$(docker_driver_builder)"
		if ! docker image inspect "$(local_tag "$dep" "$platform")" >/dev/null 2>&1; then
			build_local "$dep" "$platform" || return 1
		fi
	fi

	while IFS= read -r line; do args+=("$line"); done < <(resolve_buildargs "$id" "$platform" local)
	if [ -z "$dep" ]; then
		while IFS= read -r line; do args+=("$line"); done < <(cache_args "$id" "$platform" write)
	fi
	with_qemu_retry docker buildx build --platform "$platform" --load \
		${builder:+--builder "$builder"} \
		--provenance=false \
		${pull[@]+"${pull[@]}"} \
		${args[@]+"${args[@]}"} \
		-f "$(m_dockerfile "$id")" -t "$tag" "$(m_context "$id")"
}

publish_image() { # id
	local id="$1" image line
	local args=() tags=() platforms
	image="$(m_image "$id")"
	platforms="$(m_platforms "$id")"
	tags=(-t "$image")
	[ -n "${DEPOT_TAG_SUFFIX:-}" ] && tags+=(-t "${image}-${DEPOT_TAG_SUFFIX}")

	# Dependencies are published first: rely on their public tag.
	while IFS= read -r line; do args+=("$line"); done < <(resolve_buildargs "$id" "" public)
	# Reuse the layers built (and cached) during the test phase.
	local plat
	for plat in ${platforms//,/ }; do
		while IFS= read -r line; do args+=("$line"); done < <(cache_args "$id" "$plat")
	done

	with_qemu_retry docker buildx build --platform "$platforms" --push \
		--pull --provenance=false \
		${args[@]+"${args[@]}"} "${tags[@]}" \
		-f "$(m_dockerfile "$id")" "$(m_context "$id")"
}


# --- Parallel mode -----------------------------------------------------------
# Independent images (a root image and its dependents form one "leg") are tested by
# worker processes of this same script, each writing a log and a results file.

if [ "$JOBS" -gt 1 ] && [ -z "$RESULTS_FILE" ]; then
	TMP="$(mktemp -d)"
	LEGS=()
	for id in "${SELECTED[@]}"; do
		[ -z "$(m_depends "$id")" ] || continue
		leg="$id"
		for other in "${SELECTED[@]}"; do
			[ "$(m_depends "$other")" = "$id" ] && leg="$leg $other"
		done
		LEGS+=("$leg")
	done

	flags=()
	[ "$ALL_PLATFORMS" = "1" ] && flags+=(--all-platforms)
	[ -n "$FORCE_PLATFORM" ] && flags+=(--platform "$FORCE_PLATFORM")
	[ "$NO_BUILD" = "1" ] && flags+=(--no-build)
	[ "$KEEP" = "1" ] && flags+=(--keep)
	[ "$PUBLISH" = "1" ] && flags+=(--publish)

	export TMP_DIR="$TMP" SELF="$0"
	export FLAGS="${flags[*]:-}"
	START_PAR=$SECONDS
	# The per-leg script lives in a file: BSD xargs limits the size of a -I replacement.
	cat >"$TMP/leg.sh" <<'LEG'
#!/usr/bin/env bash
leg="$1"
name="${leg// /+}"
printf '  started:  %s\n' "$leg"
# shellcheck disable=SC2086
bash "$SELF" $FLAGS --results "$TMP_DIR/$name.res" $leg >"$TMP_DIR/$name.log" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
	printf '  finished: %s (ok)\n' "$leg"
else
	printf '  finished: %s (FAILED)\n' "$leg"
	grep -E 'FAIL|BUILD FAILED' "$TMP_DIR/$name.log" | head -6 | sed 's/^/      /'
fi
LEG
	printf '%s\n' "${LEGS[@]}" | xargs -P "$JOBS" -I{} bash "$TMP/leg.sh" "{}"

	for leg in "${LEGS[@]}"; do
		name="${leg// /+}"
		sed '/^.\[1m== Summary/,$d' "$TMP/$name.log"
	done

	printf '\n\033[1m== Summary (%ds, %d parallel jobs)\033[0m\n' $((SECONDS - START_PAR)) "$JOBS"
	failed=()
	for id in "${SELECTED[@]}"; do
		r="$(cat "$TMP"/*.res 2>/dev/null | awk -v id="$id" '$1 == id { print $2 }')"
		case "$r" in
		ok) printf '  \033[32m%-9s\033[0m %s\n' "OK" "$id" ;;
		*)
			printf '  \033[31m%-9s\033[0m %s\n' "${r:-no-result}" "$id"
			failed+=("$id")
			;;
		esac
	done
	rm -rf "$TMP"
	if [ "${#failed[@]}" -gt 0 ]; then
		printf '\n%d image(s) failed: %s\n' "${#failed[@]}" "${failed[*]}"
		exit 1
	fi
	printf '\nAll images are valid.\n'
	exit 0
fi

# --- Main loop ---------------------------------------------------------------

FAILED_IDS=()
START_ALL=$SECONDS

for id in "${SELECTED[@]}"; do
	dep="$(m_depends "$id")"
	if [ -n "$dep" ] && [ "$(get_result "$dep")" != "ok" ]; then
		set_result "$id" skipped
		printf '\n\033[33m== %s: skipped (dependency %s did not pass)\033[0m\n' "$id" "$dep"
		FAILED_IDS+=("$id")
		continue
	fi

	printf '\n\033[1m== %s\033[0m  (%s)\n' "$id" "$(m_image "$id")"
	start=$SECONDS
	ok=1

	profile_file="$ROOT/tests/profiles/$(m_profile "$id").sh"
	if [ ! -f "$profile_file" ]; then
		echo "  test profile not found: $profile_file" >&2
		set_result "$id" failed
		FAILED_IDS+=("$id")
		continue
	fi

	for platform in $(platforms_to_test "$id"); do
		printf '  -> %s\n' "$platform"
		tag="$(local_tag "$id" "$platform")"

		if [ "$NO_BUILD" = "0" ]; then
			printf '  build...\n'
			if ! build_log="$(build_local "$id" "$platform" 2>&1)"; then
				printf '%s\n' "$build_log" | tail -n 40 | sed 's/^/     | /'
				printf '  \033[31mBUILD FAILED\033[0m\n'
				ok=0
				continue
			fi
		fi

		# Size budget: an image must not silently grow.
		maxsize="$(m_maxsize "$id")"
		size_mb=$(($(docker image inspect "$tag" --format '{{.Size}}' 2>/dev/null || echo 0) / 1000000))
		if [ -n "$maxsize" ] && [ "$size_mb" -gt "$maxsize" ]; then
			printf '    \033[31mFAIL\033[0m image size %d MB exceeds its budget of %d MB\n' "$size_mb" "$maxsize"
			ok=0
		else
			printf '    size: %d MB (budget %s MB)\n' "$size_mb" "${maxsize:-none}"
		fi

		# shellcheck disable=SC1090
		source "$profile_file"
		IMG="$tag"
		PLATFORM="$platform"
		EXPECT="$(m_expect "$id")"
		TESTS_FAILED=0
		TESTS_PASSED=0
		profile_main
		cleanup_containers

		printf '  %s: %d passed, %d failed\n' "$platform" "$TESTS_PASSED" "$TESTS_FAILED"
		[ "$TESTS_FAILED" -eq 0 ] || ok=0
		[ "$TESTS_PASSED" -gt 0 ] || ok=0 # a profile that tests nothing is an error
	done

	if [ "$ok" = "1" ]; then
		set_result "$id" ok
		if [ "$PUBLISH" = "1" ]; then
			printf '  publishing %s ...\n' "$(m_image "$id")"
			if ! publish_image "$id"; then
				set_result "$id" publish-failed
				FAILED_IDS+=("$id")
			fi
		fi
	else
		set_result "$id" failed
		FAILED_IDS+=("$id")
	fi
	printf '  -> %s (%ds)\n' "$(get_result "$id")" $((SECONDS - start))
done

# --- Results file (worker mode) ----------------------------------------------

if [ -n "$RESULTS_FILE" ]; then
	: >"$RESULTS_FILE"
	for id in "${SELECTED[@]}"; do
		printf '%s %s\n' "$id" "$(get_result "$id")" >>"$RESULTS_FILE"
	done
fi

# --- Cleanup -----------------------------------------------------------------

if [ "$KEEP" = "0" ] && [ "$NO_BUILD" = "0" ]; then
	for id in "${SELECTED[@]}"; do
		for platform in linux/amd64 linux/arm64; do
			docker image rm -f "$(local_tag "$id" "$platform")" >/dev/null 2>&1 || true
		done
	done
fi

# --- Summary -----------------------------------------------------------------

printf '\n\033[1m== Summary (%ds)\033[0m\n' $((SECONDS - START_ALL))
for id in "${SELECTED[@]}"; do
	r="$(get_result "$id")"
	case "$r" in
	ok) printf '  \033[32m%-9s\033[0m %s\n' "OK" "$id" ;;
	*) printf '  \033[31m%-9s\033[0m %s\n' "${r:-?}" "$id" ;;
	esac
done

if [ "${#FAILED_IDS[@]}" -gt 0 ]; then
	printf '\n%d image(s) failed: %s\n' "${#FAILED_IDS[@]}" "${FAILED_IDS[*]}"
	exit 1
fi
printf '\nAll images are valid.\n'
