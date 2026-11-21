# Verbatim copy of the install script of the 'minecraft-forge' catalog entry (panel/config/depot.php).
# Keep it in sync: the e2e tests run it for real inside the installers:debian image.
#!/bin/bash
apt update
apt install -y curl jq openjdk-21-jre-headless

cd /mnt/server

INSTALLER_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${MINECRAFT_VERSION}-${FORGE_VERSION}/forge-${MINECRAFT_VERSION}-${FORGE_VERSION}-installer.jar"
curl -fsSL -o forge-installer.jar "${INSTALLER_URL}"
java -jar forge-installer.jar --installServer
rm -f forge-installer.jar forge-installer.jar.log
echo "eula=true" > eula.txt
