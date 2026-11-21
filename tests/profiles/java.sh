# Profile: Java runtime. EXPECT = "<major>", "<major>:openj9" or "<major>:jre" (JRE only, no javac)
profile_main() {
	local major="${EXPECT%%:*}" openj9=0 jre=0
	[[ "$EXPECT" == *:openj9 ]] && openj9=1
	[[ "$EXPECT" == *:jre ]] && jre=1

	local vpattern
	if [ "$major" = "8" ]; then
		vpattern='version "1\.8\.'
	else
		vpattern="version \"${major}([.\"+-]|\$)"
	fi

	common_identity_checks
	common_entrypoint_checks

	check_out "java is version $major" "$vpattern" run_sh bash 'java -version 2>&1'
	check_out "the entrypoint prints the Java version" "$vpattern" run_startup 'true'
	if [ "$openj9" = "1" ]; then
		check_out "the JVM is OpenJ9 (Semeru)" 'OpenJ9' run_sh bash 'java -version 2>&1'
	else
		check_not_out "the JVM is HotSpot (not OpenJ9)" 'OpenJ9' run_sh bash 'java -version 2>&1'
	fi

	if [ "$jre" = "1" ]; then
		check_tools "tools are present" bash java keytool lsof curl openssl git tar sqlite3 fc-list ip
		check_not_out "this is a JRE flavour (no javac)" 'javac' run_sh bash 'command -v javac'
		check_out "java prints its settings" 'java\.home' run_sh bash 'java -XshowSettings:properties -version 2>&1'
		check_out "the Java truststore contains root authorities" '^trusted:[1-9][0-9]*$' \
			run_sh bash 'cacerts="$JAVA_HOME/lib/security/cacerts"; [ -f "$cacerts" ] || cacerts="$JAVA_HOME/jre/lib/security/cacerts"; echo "trusted:$(keytool -list -keystore "$cacerts" -storepass changeit 2>/dev/null | grep -c trustedCertEntry)"'
	else
		check_tools "tools are present" bash java javac lsof curl openssl git tar sqlite3 fc-list ip

		check_out "java runs a compiled program" '^java-ok:2$' \
			run_sh bash 'cd /tmp && printf "public class H{public static void main(String[] a){System.out.println(\"java-ok:\"+a.length);}}\n" > H.java && javac H.java && java H x y'

		check_out "the Java truststore contains root authorities" '^trusted:[1-9][0-9]*$' \
			run_sh bash 'cd /tmp && cat > T.java <<JAVA
import javax.net.ssl.*; import java.security.KeyStore;
public class T { public static void main(String[] a) throws Exception {
  TrustManagerFactory f = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
  f.init((KeyStore) null);
  int n = 0; for (TrustManager t : f.getTrustManagers()) if (t instanceof X509TrustManager) n += ((X509TrustManager) t).getAcceptedIssuers().length;
  System.out.println("trusted:" + n); } }
JAVA
javac T.java && java T'
	fi

	check "Minecraft-like startup works (Xms/Xmx through STARTUP)" \
		run_startup 'java -Xms16M -Xmx{{SERVER_MEMORY}}M -version' -e SERVER_MEMORY=96

	check "fontconfig works (needed by AWT and map plugins)" run_sh bash 'fc-list >/dev/null'
	check "the apt cache is empty (lean image)" \
		run_sh bash '[ -z "$(ls -A /var/lib/apt/lists 2>/dev/null | grep -v lock | grep -v partial)" ]'

	if [ "${DEPOT_TEST_E2E:-0}" = "1" ]; then
		# shellcheck source=tests/e2e/minecraft.sh
		source "$ROOT/tests/e2e/minecraft.sh"
		e2e_minecraft
	fi
}
