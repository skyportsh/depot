# Profile: Debian installer (installers/debian) - amd64 only (i386 libraries for steamcmd)
profile_main() {
	check_out "image is labelled (OCI source)" 'github.com/skyportsh/depot' \
		docker inspect -f '{{index .Config.Labels "org.opencontainers.image.source"}}' "$IMG"
	check_out "Debian 13 (trixie) base" '^13' run_sh bash 'cat /etc/debian_version'
	check_tools "installation tools are present" bash curl git wget tar apt-get
	check_out "the i386 architecture is enabled (steamcmd)" 'i386' \
		run_sh bash 'dpkg --print-foreign-architectures'
	check "steamcmd libraries are installed (lib32gcc-s1, libsdl2:i386)" \
		run_sh bash 'dpkg -s lib32gcc-s1 libsdl2-2.0-0:i386 >/dev/null'
	check "root CA certificates are installed" run_sh bash 'test -s /etc/ssl/certs/ca-certificates.crt'
	check "the apt cache is empty (lean image)" \
		run_sh bash '[ -z "$(ls -A /var/lib/apt/lists 2>/dev/null | grep -v lock | grep -v partial)" ]'
	network_check "curl validates TLS (https://github.com)" run_sh bash 'curl -fsSI https://github.com >/dev/null'
}
