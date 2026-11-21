# Profile: Rust (games/rust) - amd64. Specific entrypoint + RCON wrapper.
profile_main() {
	common_identity_checks

	check_out "supported Debian 13 (trixie) base" '^13' run_sh bash 'cat /etc/debian_version'
	check_out "Node.js (RCON wrapper) is a supported version (>= 22)" '^v(2[2-9]|[3-9][0-9])\.' \
		run_sh bash 'node -v'
	check_out "the ws module loads" '^ws-ok' \
		run_sh bash 'node -e "const w=require(\"ws\");console.log(\"ws-ok\", typeof w.WebSocket)"'
	check "32-bit libraries required by steamcmd are present" \
		run_sh bash 'dpkg -s lib32gcc-s1 lib32stdc++6 libsdl2-2.0-0:i386 libgdiplus >/dev/null'
	check_tools "tools are present" bash curl unzip ip node
	check "root CA certificates are installed (Oxide/Carbon downloads)" \
		run_sh bash 'test -s /etc/ssl/certs/ca-certificates.crt'
	network_check "curl validates TLS (https://github.com)" run_sh bash 'curl -fsSI https://github.com >/dev/null'

	# steamcmd is installed by the panel install script: simulate it.
	local stub='mkdir -p /home/container/steamcmd && printf "#!/bin/bash\necho STEAMCMD-STUB \"\$@\"\n" > /home/container/steamcmd/steamcmd.sh && chmod +x /home/container/steamcmd/steamcmd.sh'

	# Fake WebRcon server: exercises the whole chain wrapper -> ws -> game.
	local fake='node -e "
const {WebSocketServer}=require(\"ws\");
const s=new WebSocketServer({port:28016});
s.on(\"connection\",(c)=>{c.on(\"message\",(m)=>{c.send(JSON.stringify({Message:\"rcon-echo:\"+JSON.parse(m).Message}))})});
" &'
	local name="depot-rust-$$"
	start_bg "$name" -e AUTO_UPDATE=1 -e RCON_PORT=28016 -e RCON_PASS=secret \
		-e 'STARTUP=sleep 60' \
		--entrypoint bash "$IMG" -c "$stub; $fake sleep 1; exec bash /entrypoint.sh"
	if wait_log "$name" 'Connected to RCON' 40; then
		pass "the wrapper connects to WebRcon (ws works)"
	else
		fail "the wrapper connects to WebRcon (ws works)" "$(docker logs "$name" 2>&1)"
	fi
	if docker logs "$name" 2>&1 | grep -q 'STEAMCMD-STUB .*+app_update 258550'; then
		pass "AUTO_UPDATE=1 calls steamcmd (app 258550)"
	else
		fail "AUTO_UPDATE=1 calls steamcmd (app 258550)" "$(docker logs "$name" 2>&1)"
	fi
	if docker logs "$name" 2>&1 | grep -q 'rcon-echo:status'; then
		pass "RCON messages reach the console"
	else
		fail "RCON messages reach the console" "$(docker logs "$name" 2>&1)"
	fi
	cleanup_containers

	check_out "AUTO_UPDATE=0 skips steamcmd" 'Not updating game server' \
		run_sh bash 'timeout 8 bash /entrypoint.sh; true' -e AUTO_UPDATE=0 -e 'STARTUP=echo rust-started' -e RCON_PORT=1 -e RCON_PASS=x

	if [ "${DEPOT_TEST_E2E:-0}" = "1" ]; then
		# shellcheck source=tests/e2e/steamcmd.sh
		source "$ROOT/tests/e2e/steamcmd.sh"
		e2e_steamcmd
	fi
}
