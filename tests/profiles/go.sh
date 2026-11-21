# Profile: Go runtime. EXPECT = minor version (e.g. 1.17)
profile_main() {
	common_identity_checks
	common_entrypoint_checks

	check_out "go is version $EXPECT" "go version go${EXPECT//./\\.}(\\.[0-9]+)? " \
		run_sh sh 'go version'
	check_out "the entrypoint prints the Go version" "go version go${EXPECT//./\\.}" \
		run_startup 'true'
	check_out "go compiles and runs a program" '^go-ok$' \
		run_sh sh 'mkdir -p /tmp/h && cd /tmp/h && printf "package main\nimport \"fmt\"\nfunc main(){fmt.Println(\"go-ok\")}\n" > main.go && go run main.go'
	check "root CA certificates are installed" run_sh sh 'test -s /etc/ssl/certs/ca-certificates.crt'
	network_check "go downloads a module through the proxy and builds against it" \
		run_sh sh 'mkdir -p /tmp/m && cd /tmp/m && printf "package main\nimport (\"fmt\"; \"github.com/google/uuid\")\nfunc main(){fmt.Println(\"go-mod-ok\", len(uuid.New().String()))}\n" > main.go && go mod init depot.test/m >/dev/null 2>&1 && go get github.com/google/uuid@v1.3.0 >/dev/null 2>&1 && go run . | grep -q "go-mod-ok 36"'
}
