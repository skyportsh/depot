#
# Copyright (c) 2024-2026 Matt James, the Matt James Foundation (MJF) and contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Stage 1: RCON wrapper dependencies (official node binary + ws module)
FROM        --platform=$TARGETOS/$TARGETARCH node:24-trixie-slim AS wrapper

RUN         npm install --prefix /wrapper --omit=dev --no-audit --no-fund ws

# Stage 2: final image
FROM        --platform=$TARGETOS/$TARGETARCH debian:trixie-slim

LABEL       author="Skyport" maintainer="container@skyport"

LABEL       org.opencontainers.image.authors="container@skyport"
LABEL       org.opencontainers.image.source="https://github.com/skyportsh/depot"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

RUN         dpkg --add-architecture i386 \
                && apt-get update \
                && apt-get upgrade -y \
                && apt-get install -y --no-install-recommends \
                    lib32gcc-s1 lib32stdc++6 libstdc++6 unzip curl ca-certificates iproute2 tzdata libgdiplus \
                    libsdl2-2.0-0:i386 \
                && rm -rf /var/lib/apt/lists/* \
                && useradd -d /home/container -m container

COPY        --from=wrapper /usr/local/bin/node /usr/local/bin/node
COPY        --from=wrapper /wrapper/node_modules /node_modules

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
COPY        ./wrapper.js /wrapper.js
CMD         [ "/bin/bash", "/entrypoint.sh" ]
