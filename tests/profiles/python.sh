# Profile: Python runtime. EXPECT = minor version (e.g. 3.11)
profile_main() {
	common_identity_checks
	common_entrypoint_checks

	check_out "python is version $EXPECT" "^Python ${EXPECT//./\\.}\\." run_sh sh 'python --version'
	check_out "the entrypoint prints the Python version" "Python ${EXPECT//./\\.}\\." run_startup 'true'
	check "pip works" run_sh sh 'pip --version'
	check_tools "build toolchain and utilities are present" sh \
		python pip gcc g++ make cmake git curl ffmpeg openssl sqlite3 tar
	check "critical standard modules are available (ssl, sqlite3, zlib, ctypes)" \
		run_sh sh 'python -c "import ssl, sqlite3, zlib, ctypes"'
	check "a virtual environment can be created" \
		run_sh sh 'python -m venv /tmp/v && /tmp/v/bin/python -c "print(1)"'
	check "gcc compiles a C program (libc headers present)" \
		run_sh sh 'cd /tmp && printf "#include <stdio.h>\nint main(){puts(\"c-ok\");return 0;}\n" > t.c && gcc t.c -o t && ./t | grep -q c-ok'
	check "root CA certificates are installed" run_sh sh 'test -s /etc/ssl/certs/ca-certificates.crt'
	network_check "pip installs a package from PyPI and python imports it" \
		run_sh sh 'cd /home/container && pip install --no-cache-dir --disable-pip-version-check --target /home/container/pkgs six==1.16.0 >/dev/null && PYTHONPATH=/home/container/pkgs python -c "import six; print(\"pip-ok\")" | grep -q pip-ok'
}
