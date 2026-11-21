# Profile: Hytale (games/hytale) - amd64, java-25 base. Specific entrypoint.
profile_main() {
	common_identity_checks

	check_out "java 25 is present" 'version "25' run_sh bash 'java -version 2>&1'
	check_tools "tools are present" bash java unzip jq curl
	check_rc "/java.sh (the original Java entrypoint) is kept and executable" 0 \
		run_sh bash 'test -x /java.sh'

	# Fake Hytale downloader (the real binary is installed by the panel).
	local downloader='mkdir -p /home/container/hytale-downloader && cat > /home/container/hytale-downloader/hytale-downloader-linux <<EOS
#!/bin/bash
case "\$*" in
  *-print-version*) echo "2026.01.01-test" ;;
  *-download-path*)
    out="\${@: -1}"
    mkdir -p /tmp/z && cd /tmp/z && echo server > Server.txt && jar cf "/home/container/\$out" Server.txt
    ;;
esac
EOS
chmod +x /home/container/hytale-downloader/hytale-downloader-linux'

	check_out "update flow: download, extract, write the version file, then run STARTUP" 'hytale-ok' \
		run_sh bash "$downloader; bash /entrypoint.sh" -e HYTALE_PATCHLINE=release -e 'STARTUP=echo hytale-ok'
	check_out "the version file is written" '^2026\.01\.01-test$' \
		run_sh bash "$downloader; bash /entrypoint.sh >/dev/null; cat /home/container/version" -e HYTALE_PATCHLINE=release -e 'STARTUP=echo x'
	check_out "the downloaded server is extracted" 'Server.txt' \
		run_sh bash "$downloader; bash /entrypoint.sh >/dev/null; ls /home/container" -e HYTALE_PATCHLINE=release -e 'STARTUP=echo x'

	check_out "MaxViewRadius is applied to config.json with jq" '"MaxViewRadius": 12' \
		run_sh bash 'echo "{\"MaxViewRadius\":4}" > /home/container/config.json; bash /entrypoint.sh >/dev/null; cat /home/container/config.json' \
		-e HYTALE_SERVER_SESSION_TOKEN=tok -e HYTALE_MAX_VIEW_RADIUS=12 -e 'STARTUP=echo x'

	check_out "with a session token, a local HytaleServer.zip is extracted" 'Server.txt' \
		run_sh bash 'mkdir -p /tmp/z && cd /tmp/z && echo s > Server.txt && jar cf /home/container/HytaleServer.zip Server.txt && cd /home/container && bash /entrypoint.sh >/dev/null; ls /home/container' \
		-e HYTALE_SERVER_SESSION_TOKEN=tok -e 'STARTUP=echo x'
}
