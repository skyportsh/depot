# End-to-end test: install steamcmd with the real installer image, then check it in the game image.
# Sourced by the game-rust and game-source profiles when DEPOT_TEST_E2E=1. Needs internet access.
#
#   required: the steamcmd download works and every 32-bit library steamcmd links against
#             is present in the game image (ldd reports nothing missing)
#   optional: steamcmd logs in anonymously to Steam (depends on Steam being reachable from the
#             machine running the tests, so a failure is reported as a warning, with diagnostics)
#
# steamcmd is a 32-bit x86 program: on Apple Silicon (Rosetta) it cannot run, so this test is
# skipped there and enforced in CI, which runs amd64 natively.

# shellcheck source=tests/e2e/catalog.sh
source "$ROOT/tests/e2e/catalog.sh"

e2e_steamcmd() {
	local dir="$E2E_CACHE/steamcmd" volume uid out i

	if [ "$(uname -m)" != "x86_64" ] && [ "${DEPOT_E2E_FORCE_32BIT:-0}" != "1" ]; then
		printf '    skip e2e: steamcmd (32-bit x86) cannot run under emulation on this host; CI covers it\n'
		return 0
	fi

	if e2e_catalog_install steamcmd steamcmd.install.sh &&
		[ -x "$dir/steamcmd/steamcmd.sh" ] && [ -f "$dir/steamcmd/linux32/steamcmd" ]; then
		pass "e2e: the install steps download steamcmd (installers:debian)"
	else
		fail "e2e: the install steps download steamcmd (installers:debian)" "$(tail -20 "$E2E_CACHE/steamcmd.install.log" 2>/dev/null)"
		return 0
	fi

	volume="depot-e2e-$$-${RANDOM}"
	docker volume create "$volume" >/dev/null
	uid="$(dr --entrypoint bash "$IMG" -c 'echo "$(id -u container):$(id -g container)"')"
	docker run --rm --platform "$PLATFORM" --user 0 \
		-v "$volume:/data" -v "$dir:/cache:ro" \
		--entrypoint bash "$IMG" -c "cp -a /cache/. /data/ && rm -f /data/.installed && chown -R $uid /data" >/dev/null 2>&1

	# Required: all shared libraries of the 32-bit steamcmd binary resolve in this image.
	out="$(docker run --rm --platform "$PLATFORM" --cap-drop=ALL --security-opt=no-new-privileges \
		-v "$volume:/home/container" --entrypoint bash "$IMG" \
		-c 'ldd /home/container/steamcmd/linux32/steamcmd' 2>&1)"
	if printf '%s' "$out" | grep -q 'not found'; then
		fail "e2e: every library steamcmd needs is present in this image" "$(printf '%s' "$out" | grep 'not found')"
	elif printf '%s' "$out" | grep -q 'libc.so.6'; then
		pass "e2e: every library steamcmd needs is present in this image"
	else
		fail "e2e: every library steamcmd needs is present in this image" "$out"
	fi

	# Optional: a real anonymous login (the first run also self-updates steamcmd). Up to 3 attempts.
	for i in 1 2 3; do
		out="$(docker run --rm --platform "$PLATFORM" --cap-drop=ALL --security-opt=no-new-privileges \
			-v "$volume:/home/container" --entrypoint bash "$IMG" \
			-c 'cd /home/container && ./steamcmd/steamcmd.sh +login anonymous +quit; echo "steamcmd exit code: $?"; echo "--- stderr.txt:"; cat /home/container/Steam/logs/stderr.txt 2>/dev/null | tail -15' 2>&1)"
		printf '%s' "$out" | grep -q 'Connecting anonymously to Steam Public...OK' && break
		sleep 5
	done
	if printf '%s' "$out" | grep -q 'Connecting anonymously to Steam Public...OK'; then
		pass "e2e: steamcmd logs in anonymously to Steam in this image"
	else
		printf '    warn e2e: steamcmd could not log in to Steam (Steam unreachable from this machine?); not a failure\n'
		printf '%s\n' "$out" | tail -25 | sed 's/^/           | /'
	fi
	docker volume rm -f "$volume" >/dev/null 2>&1
}
