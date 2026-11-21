FROM        --platform=$TARGETOS/$TARGETARCH debian:trixie-slim

LABEL       author="Skyport" maintainer="container@skyport"

LABEL       org.opencontainers.image.authors="container@skyport"
LABEL       org.opencontainers.image.source="https://github.com/skyportsh/depot"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

# Lean runtime image: shared libraries game servers commonly need, plus basic tooling.
# Compilers, debuggers, -dev headers, ffmpeg and SDL live in the "debian-dev" image:
# on Debian 13 the SDL2 libraries pull in Mesa and LLVM (about 300 MB).
RUN         apt-get update \
                && apt-get upgrade -y \
                && apt-get install -y --no-install-recommends \
                    ca-certificates curl wget git tar zip unzip xz-utils iproute2 net-tools netcat-traditional \
                    telnet tzdata locales sqlite3 cabextract libgcc-s1 libstdc++6 libatomic1 libicu76 \
                    libunwind8 libssl3t64 libfontconfig1 liblzo2-2 libduktape207 liblua5.3-0 libmariadb3 \
                && sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
                && locale-gen \
                && apt-get clean \
                && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man /usr/share/info \
                && useradd -m -d /home/container -s /bin/bash container

USER        container
ENV         USER=container HOME=/home/container LANG=en_US.UTF-8
WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
