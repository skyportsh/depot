# Verbatim copy of the install script of the 'minecraft-vanilla' catalog entry (panel/config/depot.php).
# Keep it in sync: the e2e tests run it for real inside the installers:debian image.
#!/bin/bash
apt update
apt install -y curl jq

cd /mnt/server

if [ -z "${MINECRAFT_VERSION}" ] || [ "${MINECRAFT_VERSION}" == "latest" ]; then
    MINECRAFT_VERSION=$(curl -sSL https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r '.latest.release')
fi

MANIFEST_URL=$(curl -sSL https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r --arg V "${MINECRAFT_VERSION}" '.versions[] | select(.id==$V) | .url')

if [ -z "${MANIFEST_URL}" ] || [ "${MANIFEST_URL}" == "null" ]; then
    echo "Could not resolve Minecraft version ${MINECRAFT_VERSION}."
    exit 1
fi

DOWNLOAD_URL=$(curl -sSL "${MANIFEST_URL}" | jq -r '.downloads.server.url')
curl -fsSL -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"
echo "eula=true" > eula.txt
