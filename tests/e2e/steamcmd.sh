# End-to-end test: install steamcmd with the real installer image, then run it in the game image
# and log in anonymously to Steam. Sourced by the game-rust and game-source profiles when
# DEPOT_TEST_E2E=1. Needs internet access.
#
# steamcmd is a 32-bit x86 program: on Apple Silicon (Rosetta) it cannot run, so this test is
# skipped there and enforced in CI, which runs amd64 natively.

E2E_CACHE="${E2E_CACHE:-$ROOT/tests/.cache}"

e2e_steamcmd() {
	local installer dir="$E2E_CACHE/steamcmd" volume name uid out

	if [ "$(uname -m)" != "x86_64" ] && [ "${DEPOT_E2E_FORCE_32BIT:-0}" != "1" ]; then
		printf '    skip e2e: steamcmd (32-bit x86) cannot run under emulation on this host; CI covers it\n'
		return 0
	fi

	installer="$(local_tag installer-debian linux/amd64)"
	if ! docker image inspect "$installer" >/dev/null 2>&1; then
		build_local installer-debian linux/amd64 >/dev/null 2>&1 || {
			fail "e2e: build the installers:debian image"
			return 0
		}
	fi

	if [ ! -x "$dir/steamcmd/steamcmd.sh" ]; then
		mkdir -p "$dir"
		if docker run --rm --platform linux/amd64 -v "$dir:/mnt/server" \
			-v "$ROOT/tests/e2e/steamcmd.install.sh:/install.sh:ro" \
			--entrypoint bash "$installer" /install.sh >"$dir/install.log" 2>&1 &&
			[ -x "$dir/steamcmd/steamcmd.sh" ]; then
			pass "e2e: the install steps download and bootstrap steamcmd (installers:debian)"
		else
			fail "e2e: the install steps download and bootstrap steamcmd (installers:debian)" "$(tail -20 "$dir/install.log" 2>/dev/null)"
			return 0
		fi
	else
		pass "e2e: steamcmd is already installed in the cache (installers:debian)"
	fi

	volume="depot-e2e-$$-${RANDOM}"
	docker volume create "$volume" >/dev/null
	uid="$(dr --entrypoint bash "$IMG" -c 'echo "$(id -u container):$(id -g container)"')"
	docker run --rm --platform "$PLATFORM" --user 0 \
		-v "$volume:/data" -v "$dir:/cache:ro" \
		--entrypoint bash "$IMG" -c "cp -a /cache/. /data/ && chown -R $uid /data" >/dev/null 2>&1

	out="$(docker run --rm --platform "$PLATFORM" --cap-drop=ALL --security-opt=no-new-privileges \
		-v "$volume:/home/container" --entrypoint bash "$IMG" \
		-c 'cd /home/container && ./steamcmd/steamcmd.sh +login anonymous +quit' 2>&1)"
	if printf '%s' "$out" | grep -q 'Connecting anonymously to Steam Public...OK'; then
		pass "e2e: steamcmd runs in this image and logs in anonymously to Steam"
	else
		fail "e2e: steamcmd runs in this image and logs in anonymously to Steam" "$(printf '%s' "$out" | tail -15)"
	fi
	docker volume rm -f "$volume" >/dev/null 2>&1
}
