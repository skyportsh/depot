# Same steps as the Steam-based install scripts of the catalog (panel/config/depot.php: rust, garrysmod,
# tf2...), without the final app_update, so the test does not download several gigabytes.
apt update
apt install -y curl tar lib32gcc-s1 lib32stdc++6

mkdir -p /mnt/server/steamcmd
cd /mnt/server/steamcmd
curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz
./steamcmd.sh +force_install_dir /mnt/server +login anonymous +quit
