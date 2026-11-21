# End-to-end tests for the Java images: replay the Minecraft entries of the panel catalog
# (vanilla, Paper, Forge) with their real install scripts, then boot the server on the image
# under test. Sourced by tests/profiles/java.sh when DEPOT_TEST_E2E=1.

# shellcheck source=tests/e2e/catalog.sh
source "$ROOT/tests/e2e/catalog.sh"

MC_STARTUP='java -Xms128M -Xmx{{SERVER_MEMORY}}M -Dterminal.jline=false -Dterminal.ansi=true -jar {{SERVER_JARFILE}}'
MC_READY='Done \([0-9.,]+s\)!'

# Vanilla version used for each Java major: the oldest server that runs on that JVM.
# Semeru 17 and older have no Flight Recorder, which Minecraft >= 1.18 needs, so they get 1.17.1 or older.
e2e_vanilla_version() { # major flavor
	local major="$1" flavor="$2"
	if [ "$flavor" = "openj9" ]; then
		case "$major" in
		8) echo "1.12.2" ;;
		11) echo "1.16.5" ;;
		16 | 17) echo "1.17.1" ;;
		*) echo "1.18.2" ;;
		esac
		return
	fi
	case "$major" in
	8) echo "1.12.2" ;;
	11) echo "1.16.5" ;;
	16) echo "1.17.1" ;;
	17) echo "1.20.4" ;;
	18 | 19) echo "1.18.2" ;;
	*) echo "1.21.4" ;;
	esac
}

e2e_minecraft() {
	local major="${EXPECT%%:*}" flavor="hotspot" version
	[[ "$EXPECT" == *:openj9 ]] && flavor="openj9"
	[[ "$EXPECT" == *:jre ]] && flavor="jre"
	version="$(e2e_vanilla_version "$major" "$flavor")"

	# OpenJ9's JIT cannot run under x86 emulation on Apple Silicon (it aborts); CI runs it natively.
	if [ "$flavor" = "openj9" ] && [ "$PLATFORM" != "$(host_platform)" ]; then
		printf '    skip e2e: OpenJ9 cannot run under emulation on this host; CI covers it\n'
		return 0
	fi

	# --- Vanilla ---------------------------------------------------------------
	if e2e_catalog_install "vanilla-$version" minecraft-vanilla.install.sh \
		-e SERVER_JARFILE=server.jar -e "MINECRAFT_VERSION=$version"; then
		pass "e2e: the vanilla install script downloads Minecraft $version (installers:debian)"
		e2e_catalog_start "Minecraft $version (vanilla)" "vanilla-$version" "$MC_READY" "$MC_STARTUP" \
			-e SERVER_JARFILE=server.jar
	else
		fail "e2e: the vanilla install script downloads Minecraft $version (installers:debian)" \
			"$(tail -15 "$E2E_CACHE/vanilla-$version.install.log" 2>/dev/null)"
	fi

	# --- Paper (Java 21 and 25 HotSpot flavours) -------------------------------
	if [ "$flavor" != "openj9" ] && { [ "$major" = "21" ] || [ "$major" = "25" ]; }; then
		if e2e_catalog_install "paper-1.21.4" minecraft-paper.install.sh \
			-e SERVER_JARFILE=server.jar -e MINECRAFT_VERSION=1.21.4 -e BUILD_NUMBER=latest; then
			pass "e2e: the Paper install script downloads and verifies Paper 1.21.4 (installers:debian)"
			e2e_catalog_start "Paper 1.21.4" "paper-1.21.4" "$MC_READY" "$MC_STARTUP" -e SERVER_JARFILE=server.jar
		else
			fail "e2e: the Paper install script downloads and verifies Paper 1.21.4 (installers:debian)" \
				"$(tail -15 "$E2E_CACHE/paper-1.21.4.install.log" 2>/dev/null)"
		fi
	fi

	# --- Paper "latest" resolution (once, on the plain Java 21 image) ----------
	if [ "$EXPECT" = "21" ]; then
		rm -rf "$E2E_CACHE/paper-latest" "$E2E_CACHE/paper-latest.install.log"
		if e2e_catalog_install "paper-latest" minecraft-paper.install.sh \
			-e SERVER_JARFILE=server.jar -e MINECRAFT_VERSION=latest -e BUILD_NUMBER=latest &&
			[ "$(head -c 2 "$E2E_CACHE/paper-latest/server.jar")" = "PK" ]; then
			pass "e2e: the Paper install script resolves 'latest' to a real, verified jar"
		else
			fail "e2e: the Paper install script resolves 'latest' to a real, verified jar" \
				"$(tail -15 "$E2E_CACHE/paper-latest.install.log" 2>/dev/null)"
		fi
		rm -rf "$E2E_CACHE/paper-latest"
	fi

	# --- Forge 1.20.1 (Java 17 and 21 HotSpot flavours) ------------------------
	if [ "$flavor" != "openj9" ] && { [ "$major" = "17" ] || [ "$major" = "21" ]; }; then
		if e2e_catalog_install "forge-1.20.1" minecraft-forge.install.sh \
			-e MINECRAFT_VERSION=1.20.1 -e FORGE_VERSION=47.2.20; then
			pass "e2e: the Forge install script installs Forge 1.20.1-47.2.20 (installers:debian)"
			e2e_catalog_start "Forge 1.20.1-47.2.20" "forge-1.20.1" "$MC_READY" \
				'java -Xms128M -Xmx{{SERVER_MEMORY}}M -Dterminal.jline=false -Dterminal.ansi=true @user_jvm_args.txt @libraries/net/minecraftforge/forge/{{MINECRAFT_VERSION}}-{{FORGE_VERSION}}/unix_args.txt nogui' \
				-e MINECRAFT_VERSION=1.20.1 -e FORGE_VERSION=47.2.20
		else
			fail "e2e: the Forge install script installs Forge 1.20.1-47.2.20 (installers:debian)" \
				"$(tail -15 "$E2E_CACHE/forge-1.20.1.install.log" 2>/dev/null)"
		fi
	fi
}
