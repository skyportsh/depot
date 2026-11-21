#!/usr/bin/env bash
# Helpers shared by the test profiles. Meant to be sourced, not executed.
#
# Variables expected (set by tests/run.sh):
#   IMG       reference of the image under test
#   PLATFORM  docker platform (linux/amd64, linux/arm64)
#   EXPECT    "expected" value from the manifest (version, ...)

TESTS_FAILED=0
TESTS_PASSED=0
CONTAINERS=()

DEPOT_TEST_NETWORK="${DEPOT_TEST_NETWORK:-1}"

# --- Output ------------------------------------------------------------------

pass() {
	TESTS_PASSED=$((TESTS_PASSED + 1))
	printf '    \033[32mok\033[0m   %s\n' "$1"
}

fail() {
	TESTS_FAILED=$((TESTS_FAILED + 1))
	printf '    \033[31mFAIL\033[0m %s\n' "$1"
	if [ -n "${2:-}" ]; then
		printf '%s\n' "$2" | head -n 15 | sed 's/^/           | /'
	fi
}

# --- Running things in the container -----------------------------------------

# Run a throwaway container, hardened like in production
# (no capabilities, no privilege escalation).
dr() {
	docker run --rm --platform "$PLATFORM" \
		--cap-drop=ALL --security-opt=no-new-privileges \
		"$@"
}

# Run the image entrypoint with a STARTUP command.
#   run_startup 'echo {{X}}' [docker options...]
run_startup() {
	local startup="$1"
	shift
	dr -e "STARTUP=$startup" "$@" "$IMG"
}

# Run a shell script instead of the entrypoint.
#   run_sh bash 'echo hi' [docker options...]
run_sh() {
	local shell="$1" script="$2"
	shift 2
	dr "$@" --entrypoint "$shell" "$IMG" -c "$script"
}

# Start a background container (cleaned up automatically).
#   start_bg NAME [docker options...] IMAGE command...
start_bg() {
	local name="$1"
	shift
	CONTAINERS+=("$name")
	docker run -d --name "$name" --platform "$PLATFORM" \
		--cap-drop=ALL --security-opt=no-new-privileges "$@" >/dev/null
}

# Wait for a pattern to show up in a container's logs.
wait_log() {
	local name="$1" pattern="$2" timeout="${3:-30}" i=0
	while [ "$i" -lt "$timeout" ]; do
		if docker logs "$name" 2>&1 | grep -qE -- "$pattern"; then
			return 0
		fi
		sleep 1
		i=$((i + 1))
	done
	return 1
}

cleanup_containers() {
	local c
	for c in ${CONTAINERS[@]+"${CONTAINERS[@]}"}; do
		[ -n "$c" ] && docker rm -f "$c" >/dev/null 2>&1
	done
	CONTAINERS=()
}

# --- Assertions --------------------------------------------------------------

# check "name" command...: the command must succeed.
check() {
	local name="$1" out
	shift
	if out=$("$@" 2>&1); then
		pass "$name"
	else
		fail "$name" "$out"
	fi
}

# check_out "name" "regex" command...: the output (stdout+stderr) must match.
check_out() {
	local name="$1" pattern="$2" out
	shift 2
	out=$("$@" 2>&1)
	if printf '%s' "$out" | grep -qE -- "$pattern"; then
		pass "$name"
	else
		fail "$name (expected pattern: $pattern)" "$out"
	fi
}

# check_not_out "name" "regex" command...: the output must NOT match.
check_not_out() {
	local name="$1" pattern="$2" out
	shift 2
	out=$("$@" 2>&1)
	if printf '%s' "$out" | grep -qE -- "$pattern"; then
		fail "$name (forbidden pattern: $pattern)" "$out"
	else
		pass "$name"
	fi
}

# check_rc "name" code command...: exact exit code.
check_rc() {
	local name="$1" expected="$2" out rc
	shift 2
	out=$("$@" 2>&1)
	rc=$?
	if [ "$rc" -eq "$expected" ]; then
		pass "$name"
	else
		fail "$name (exit code $rc, expected $expected)" "$out"
	fi
}

# check_tools "name" shell tool...: every tool is in the PATH.
check_tools() {
	local name="$1" shell="$2" tool missing=""
	shift 2
	for tool in "$@"; do
		if ! run_sh "$shell" "command -v $tool >/dev/null" >/dev/null 2>&1; then
			missing="$missing $tool"
		fi
	done
	if [ -z "$missing" ]; then
		pass "$name"
	else
		fail "$name (missing:$missing)"
	fi
}

# --- Common checks -----------------------------------------------------------

# Metadata and identity of a "runtime" image (non-root user).
common_identity_checks() {
	check_out "image is labelled (OCI source)" 'github.com/skyportsh/depot' \
		docker inspect -f '{{index .Config.Labels "org.opencontainers.image.source"}}' "$IMG"

	check_out "non-root user 'container', correct HOME and workdir" \
		'^container:[1-9][0-9]*:/home/container:/home/container$' \
		run_sh sh 'echo "$(id -un):$(id -u):$HOME:$(pwd)"'

	check "home directory is writable" \
		run_sh sh 'touch /home/container/.depot-write-test && rm /home/container/.depot-write-test'
}

# Contract of the shared entrypoint (STARTUP, TZ, INTERNAL_IP, exit codes...).
# Not used for the game-specific entrypoints (see their profiles).
common_entrypoint_checks() {
	check_out "STARTUP: {{VARIABLES}} are replaced" 'hello-skyport' \
		run_startup 'echo hello-{{WHO}}' -e WHO=skyport

	check_out "STARTUP: an unset variable becomes empty" '\[\]' \
		run_startup 'echo [{{DEPOT_UNSET_VARIABLE}}]'

	check_out "STARTUP: quotes are handled" '^a b$' \
		run_startup 'echo "a b"'

	check_out "STARTUP: a variable value is never interpreted as shell code" \
		'\$\(echo PWNED\)' \
		run_startup 'echo {{X}}' -e 'X=$(echo PWNED)'

	check_not_out "STARTUP: no command execution through a value (backticks)" \
		'^PWNED$' \
		run_startup 'echo {{X}}' -e 'X=`echo PWNED`'

	check_out "TZ defaults to UTC" '(^|[[:space:]])UTC$' \
		run_startup 'printenv TZ'

	check_out "custom TZ is honoured (tzdata installed)" 'CES?T' \
		run_startup 'date +%Z' -e TZ=Europe/Paris

	check_out "INTERNAL_IP is set (IPv4)" '(^|[[:space:]])[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
		run_startup 'printenv INTERNAL_IP'

	check_rc "the command exit code is propagated (exit 1)" 1 \
		run_startup 'false'

	check_rc "an unknown command fails (exit 127)" 127 \
		run_startup 'depot-nonexistent-command'

	check_rc "a successful command returns 0" 0 \
		run_startup 'true'
}

# Optional network test (DEPOT_TEST_NETWORK=0 to disable).
network_check() {
	[ "$DEPOT_TEST_NETWORK" = "1" ] || return 0
	check "$1" "${@:2}"
}
