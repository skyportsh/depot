# Verbatim copy of the install script of the 'minecraft-paper' catalog entry (panel/config/depot.php).
# Keep it in sync: the e2e tests run it for real inside the installers:debian image.
#!/bin/bash
apt update
apt install -y curl jq

cd /mnt/server

API="https://fill.papermc.io/v3/projects/paper"

if [ -z "${MINECRAFT_VERSION}" ] || [ "${MINECRAFT_VERSION}" == "latest" ]; then
    # Newest stable version (skip release candidates and pre-releases).
    MINECRAFT_VERSION=$(curl -fsSL "${API}" | jq -r '[.versions[][] | select(test("-(rc|pre|snapshot)") | not)] | .[0]')
fi

if [ -z "${BUILD_NUMBER}" ] || [ "${BUILD_NUMBER}" == "latest" ]; then
    # Newest stable build of that version.
    BUILD_JSON=$(curl -fsSL "${API}/versions/${MINECRAFT_VERSION}/builds" | jq -c '[.[] | select(.channel == "STABLE")] | .[0]')
else
    BUILD_JSON=$(curl -fsSL "${API}/versions/${MINECRAFT_VERSION}/builds/${BUILD_NUMBER}")
fi

DOWNLOAD_URL=$(echo "${BUILD_JSON}" | jq -r '.downloads["server:default"].url')
EXPECTED_SHA256=$(echo "${BUILD_JSON}" | jq -r '.downloads["server:default"].checksums.sha256')

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" == "null" ]; then
    echo "Could not resolve a Paper download for version ${MINECRAFT_VERSION} (build ${BUILD_NUMBER:-latest})."
    exit 1
fi

curl -fsSL -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"

if ! echo "${EXPECTED_SHA256}  ${SERVER_JARFILE}" | sha256sum -c -; then
    echo "Checksum mismatch for the downloaded Paper jar."
    rm -f "${SERVER_JARFILE}"
    exit 1
fi

echo "eula=true" > eula.txt
