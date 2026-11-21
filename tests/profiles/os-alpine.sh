# Profile: Alpine base image (oses/alpine)
profile_main() {
	common_identity_checks
	common_entrypoint_checks

	check_out "default shell is ash (CMD)" '/bin/ash' \
		docker inspect -f '{{json .Config.Cmd}}' "$IMG"
	check "tzdata is installed" run_sh sh 'test -e /usr/share/zoneinfo/Europe/Paris'
	check "root CA certificates are installed" run_sh sh 'test -s /etc/ssl/certs/ca-certificates.crt'
}
