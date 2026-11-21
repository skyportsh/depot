# Profile: Alpine installer (installers/alpine) - no dedicated user and no entrypoint
profile_main() {
	check_out "image is labelled (OCI source)" 'github.com/skyportsh/depot' \
		docker inspect -f '{{index .Config.Labels "org.opencontainers.image.source"}}' "$IMG"
	check_tools "installation tools are present" sh curl git jq wget tar
	check_out "jq works" '^2$' run_sh sh 'echo "{\"a\":2}" | jq .a'
	check "git works" run_sh sh 'git --version'
	check "root CA certificates are installed" run_sh sh 'test -s /etc/ssl/certs/ca-certificates.crt'
	network_check "curl validates TLS (https://github.com)" run_sh sh 'curl -fsSI https://github.com >/dev/null'
}
