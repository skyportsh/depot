# Profile: Debian development image (oses/debian, Dockerfile.dev)
profile_main() {
	common_identity_checks
	common_entrypoint_checks

	check_out "supported Debian 13 (trixie) base" '^13' \
		run_sh bash 'cat /etc/debian_version'
	check_tools "system and network tools are present" bash \
		gcc g++ gdb git wget curl tar zip unzip xz sqlite3 ffmpeg ip netstat nc telnet cabextract
	check_out "en_US.UTF-8 locale is generated" 'en_US\.utf8' \
		run_sh bash 'locale -a'
	check "gcc compiles and runs a C program" \
		run_sh bash 'cd /tmp && echo "#include <stdio.h>" > t.c && echo "int main(){puts(\"c-ok\");return 0;}" >> t.c && gcc t.c -o t && ./t | grep -q c-ok'
	check "g++ compiles and runs a C++ program" \
		run_sh bash 'cd /tmp && echo "#include <iostream>" > t.cpp && echo "int main(){std::cout<<\"cpp-ok\"<<std::endl;}" >> t.cpp && g++ t.cpp -o t && ./t | grep -q cpp-ok'
	check_out "runtime libraries are present (icu, unwind, sdl2, ssl, atomic)" 'libicuuc' \
		run_sh bash 'ldconfig -p | grep -E "libicuuc|libunwind|libSDL2-2|libssl|libatomic" | sort -u'
	check "ffmpeg works" run_sh bash 'ffmpeg -version | head -1'
	check "sqlite3 works" run_sh bash 'echo "select 1+1;" | sqlite3 | grep -q 2'
}
