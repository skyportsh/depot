# Profile: Node.js runtime. EXPECT = major version
profile_main() {
	common_identity_checks
	common_entrypoint_checks

	check_out "node is version $EXPECT" "^v${EXPECT}\\." run_sh sh 'node -v'
	check_out "the entrypoint prints the Node version" "^v${EXPECT}\\." run_startup 'true'
	check "npm works" run_sh sh 'npm -v'
	check_tools "tools are present" sh node npm git curl ffmpeg openssl sqlite3 tar
	check_out "node runs code (crypto, fs, zlib, https)" '^node-ok$' \
		run_sh sh 'cd /tmp && node -e "const c=require(\"crypto\"),f=require(\"fs\"),z=require(\"zlib\");require(\"https\");f.writeFileSync(\"x\",z.gzipSync(c.createHash(\"sha256\").update(\"a\").digest(\"hex\")));if(f.statSync(\"x\").size>0)console.log(\"node-ok\")"'
	check "npm init works in the home directory" \
		run_sh sh 'cd /home/container && npm init -y >/dev/null && rm package.json'
	check "ffmpeg works" run_sh sh 'ffmpeg -version >/dev/null'
	check "root CA certificates are installed" run_sh sh 'test -s /etc/ssl/certs/ca-certificates.crt'
	network_check "npm installs a package from the registry and node loads it" \
		run_sh sh 'cd /home/container && npm install --no-audit --no-fund --loglevel=error is-number@7.0.0 && node -e "if (require(\"is-number\")(5)) console.log(\"npm-ok\")" | grep -q npm-ok'
}
