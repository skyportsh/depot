# Shared helpers for the end-to-end tests that replay the panel catalog:
# run a real install script in the installers:debian image, then start the result in the
# image under test and wait for the game to report that it is ready.
#
# Needs internet access. Downloads are cached in tests/.cache. Safe to use from parallel workers.

E2E_CACHE="${E2E_CACHE:-$ROOT/tests/.cache}"
E2E_INSTALLER_PLATFORM="linux/amd64" # installers/debian is amd64 only

# Run a command while holding a lock (parallel workers share the cache and the installer image).
e2e_with_lock() { # name command...
	local lock="$E2E_CACHE/.lock-$1" i=0
	shift
	mkdir -p "$E2E_CACHE"
	while ! mkdir "$lock" 2>/dev/null; do
		sleep 2
		i=$((i + 1))
		[ "$i" -lt 600 ] || break
	done
	"$@"
	local rc=$?
	rmdir "$lock" 2>/dev/null
	return $rc
}

# The real installers:debian image, built from this repository (printed on stdout).
e2e_installer_image() {
	local tag
	tag="$(local_tag installer-debian "$E2E_INSTALLER_PLATFORM")"
	if ! docker image inspect "$tag" >/dev/null 2>&1; then
		e2e_with_lock installer-image e2e_build_installer >/dev/null 2>&1 || return 1
	fi
	echo "$tag"
}

e2e_build_installer() {
	docker image inspect "$(local_tag installer-debian "$E2E_INSTALLER_PLATFORM")" >/dev/null 2>&1 ||
		build_local installer-debian "$E2E_INSTALLER_PLATFORM"
}

# e2e_catalog_install <case> <fixture> [docker options...]
# Runs tests/e2e/<fixture> inside installers:debian with /mnt/server mapped to the cache of <case>.
e2e_catalog_install() {
	e2e_with_lock "case-$1" e2e_catalog_install_locked "$@"
}

e2e_catalog_install_locked() {
	local casename="$1" fixture="$2" dir installer
	shift 2
	dir="$E2E_CACHE/$casename"
	[ -f "$dir/.installed" ] && return 0
	installer="$(e2e_installer_image)" || return 1
	rm -rf "$dir"
	mkdir -p "$dir"
	if docker run --rm --platform "$E2E_INSTALLER_PLATFORM" \
		-v "$dir:/mnt/server" \
		-v "$ROOT/tests/e2e/$fixture:/install.sh:ro" \
		"$@" --entrypoint bash "$installer" /install.sh >"$E2E_CACHE/$casename.install.log" 2>&1; then
		touch "$dir/.installed"
		return 0
	fi
	return 1
}

# Seconds to wait for a game to become ready (only native platforms run these tests).
e2e_ready_timeout() { echo 300; }

# e2e_catalog_start <label> <case> <ready regex> <startup> [docker options...]
# Copies the installed files into a volume owned by the image's "container" user, starts the
# image with the catalog STARTUP and waits for the ready line.
e2e_catalog_start() {
	local label="$1" casename="$2" ready="$3" startup="$4" volume name uid out
	shift 4
	volume="depot-e2e-$$-${RANDOM}"
	name="depot-e2e-$$-${RANDOM}"
	CONTAINERS+=("$name")
	docker volume create "$volume" >/dev/null

	uid="$(dr --entrypoint bash "$IMG" -c 'echo "$(id -u container):$(id -g container)"')"
	docker run --rm --platform "$PLATFORM" --user 0 \
		-v "$volume:/data" -v "$E2E_CACHE/$casename:/cache:ro" \
		--entrypoint bash "$IMG" -c "cp -a /cache/. /data/ && rm -f /data/.installed && chown -R $uid /data" >/dev/null 2>&1

	docker run -d --name "$name" --platform "$PLATFORM" --memory 2g \
		--cap-drop=ALL --security-opt=no-new-privileges \
		-v "$volume:/home/container" \
		-e SERVER_MEMORY=1024 -e "STARTUP=$startup" "$@" \
		"$IMG" >/dev/null

	if wait_log "$name" "$ready" "$(e2e_ready_timeout)"; then
		pass "e2e: $label starts on this image and reports it is ready"
	else
		fail "e2e: $label starts on this image and reports it is ready" "$(docker logs "$name" 2>&1 | tail -25)"
	fi

	out="$(docker logs "$name" 2>&1)"
	if printf '%s' "$out" | grep -qE 'UnsupportedClassVersionError|Exception in thread|OutOfMemoryError|Encountered an unexpected exception'; then
		fail "e2e: $label has no JVM error in its log" \
			"$(printf '%s' "$out" | grep -E 'UnsupportedClassVersionError|Exception in thread|OutOfMemoryError|Encountered an unexpected exception' -A2 | head -8)"
	else
		pass "e2e: $label has no JVM error in its log"
	fi

	docker rm -f "$name" >/dev/null 2>&1
	docker volume rm -f "$volume" >/dev/null 2>&1
}
