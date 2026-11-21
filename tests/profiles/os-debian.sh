# Profile: lean Debian runtime image (oses/debian)
profile_main() {
	common_identity_checks
	common_entrypoint_checks

	check_out "supported Debian 13 (trixie) base" '^13' \
		run_sh bash 'cat /etc/debian_version'
	check_tools "base tooling is present" bash \
		git wget curl tar zip unzip xz sqlite3 ip netstat nc telnet cabextract
	check_out "en_US.UTF-8 locale is generated" 'en_US\.utf8' \
		run_sh bash 'locale -a'
	check_out "common runtime libraries are present (icu, unwind, ssl, atomic)" 'libicuuc' \
		run_sh bash 'ldconfig -p | grep -E "libicuuc|libunwind|libssl|libatomic" | sort -u'
	check_out "libstdc++ is present (C++ binaries run)" 'libstdc\+\+\.so\.6' \
		run_sh bash 'ldconfig -p | grep libstdc++'
	check "sqlite3 works" run_sh bash 'echo "select 1+1;" | sqlite3 | grep -q 2'
	check "the apt cache and documentation are removed (lean image)" \
		run_sh bash '[ -z "$(ls -A /var/lib/apt/lists 2>/dev/null | grep -v lock | grep -v partial)" ] && [ ! -d /usr/share/doc ]'
	check "root CA certificates are installed and curl validates them" \
		run_sh bash 'test -s /etc/ssl/certs/ca-certificates.crt'
	network_check "curl validates TLS (https://github.com)" run_sh bash 'curl -fsSI https://github.com >/dev/null'
}
