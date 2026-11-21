# Profile: Source / steamcmd games (games/source) - amd64
profile_main() {
	common_identity_checks
	common_entrypoint_checks

	check_out "supported Debian 13 (trixie) base" '^13' run_sh bash 'cat /etc/debian_version'
	check "32-bit libraries required by steamcmd/srcds are present" \
		run_sh bash 'dpkg -s lib32gcc-s1 lib32stdc++6 lib32z1 libsdl2-2.0-0:i386 libcurl4t64:i386 libtinfo6:i386 >/dev/null'
	check_tools "tools are present" bash curl tar gdb ip nc telnet netstat

	check_out "without SRCDS_APPID no update is attempted" 'No appid set' \
		run_startup 'true'
	check_out "without STEAM_USER the anonymous user is used" 'Using anonymous user' \
		run_startup 'true'
	check_out "a defined STEAM_USER is honoured" 'user set to depotuser' \
		run_startup 'true' -e STEAM_USER=depotuser
	check_out "AUTO_UPDATE=0 skips the update" 'Not updating game server' \
		run_startup 'true' -e AUTO_UPDATE=0

	# steamcmd is installed by the panel install script: simulate it.
	check_out "AUTO_UPDATE=1 + SRCDS_APPID calls steamcmd with the right arguments, then starts the game" \
		'STEAMCMD-STUB.*\+login anonymous.*\+app_update 232250.*validate' \
		run_sh bash 'mkdir -p /home/container/steamcmd && printf "#!/bin/bash\necho STEAMCMD-STUB \"\$@\"\n" > /home/container/steamcmd/steamcmd.sh && chmod +x /home/container/steamcmd/steamcmd.sh && exec bash /entrypoint.sh' \
		-e SRCDS_APPID=232250 -e VALIDATE=1 -e 'STARTUP=echo srcds-{{SRCDS_MAP}}' -e SRCDS_MAP=de_dust2
	check_out "the game is started with STARTUP after the update" 'srcds-de_dust2' \
		run_startup 'echo srcds-{{SRCDS_MAP}}' -e SRCDS_MAP=de_dust2

	if [ "${DEPOT_TEST_E2E:-0}" = "1" ]; then
		# shellcheck source=tests/e2e/steamcmd.sh
		source "$ROOT/tests/e2e/steamcmd.sh"
		e2e_steamcmd
	fi
}
