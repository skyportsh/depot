# Skyport Depot

Skyport Depot is Skyport's maintained fork of [Pterodactyl Yolks](https://github.com/pterodactyl/yolks).
It contains the container images used by Skyport for game servers, installers, and language runtimes.

Images are published to GitHub Container Registry under the Skyport namespace:

- `ghcr.io/skyportsh/images`
- `ghcr.io/skyportsh/games`
- `ghcr.io/skyportsh/installers`

## Fork status

This repository is a fork-in-spirit of Pterodactyl Yolks and keeps the same overall layout so upstream image changes
are easy to track and port. Skyport-specific branding, metadata, logging prompts, and GHCR publishing targets live here.

## Image spaces

- `oses` — base images with common packages and the standard `container` user.
- `games` — images for specific games.
- `installers` — images used by installer scripts.
- `images` — generic runtime images such as Java, Node.js, Go, and Python.

Unless otherwise noted, images are built for both `linux/amd64` and `linux/arm64`.

## Publishing

GitHub Actions builds and publishes images to GHCR on:

- manual workflow dispatch
- scheduled rebuilds
- pushes to `master` that touch the relevant image directories

The workflows are configured for the `skyportsh` namespace and use the repository `GITHUB_TOKEN` to push packages.

## Available images

### Base OS images

- [`oses/alpine`](https://github.com/skyportsh/depot/tree/master/oses/alpine)
  - `ghcr.io/skyportsh/images:alpine`
- [`oses/debian`](https://github.com/skyportsh/depot/tree/master/oses/debian)
  - `ghcr.io/skyportsh/images:debian`

### Game images

- [`games/rust`](https://github.com/skyportsh/depot/tree/master/games/rust)
  - `ghcr.io/skyportsh/games:rust`
- [`games/source`](https://github.com/skyportsh/depot/tree/master/games/source)
  - `ghcr.io/skyportsh/games:source`
- [`games/hytale`](https://github.com/skyportsh/depot/tree/master/games/hytale)
  - `ghcr.io/skyportsh/games:hytale`

### Go images

- [`go/1.14`](https://github.com/skyportsh/depot/tree/master/go/1.14)
  - `ghcr.io/skyportsh/images:go_1.14`
- [`go/1.15`](https://github.com/skyportsh/depot/tree/master/go/1.15)
  - `ghcr.io/skyportsh/images:go_1.15`
- [`go/1.16`](https://github.com/skyportsh/depot/tree/master/go/1.16)
  - `ghcr.io/skyportsh/images:go_1.16`
- [`go/1.17`](https://github.com/skyportsh/depot/tree/master/go/1.17)
  - `ghcr.io/skyportsh/images:go_1.17`

### Java images

- [`java/8`](https://github.com/skyportsh/depot/tree/master/java/8)
  - `ghcr.io/skyportsh/images:java_8`
- [`java/8j9`](https://github.com/skyportsh/depot/tree/master/java/8j9)
  - `ghcr.io/skyportsh/images:java_8j9`
- [`java/11`](https://github.com/skyportsh/depot/tree/master/java/11)
  - `ghcr.io/skyportsh/images:java_11`
- [`java/11j9`](https://github.com/skyportsh/depot/tree/master/java/11j9)
  - `ghcr.io/skyportsh/images:java_11j9`
- [`java/16`](https://github.com/skyportsh/depot/tree/master/java/16)
  - `ghcr.io/skyportsh/images:java_16`
- [`java/16j9`](https://github.com/skyportsh/depot/tree/master/java/16j9)
  - `ghcr.io/skyportsh/images:java_16j9`
- [`java/17`](https://github.com/skyportsh/depot/tree/master/java/17)
  - `ghcr.io/skyportsh/images:java_17`
- [`java/17j9`](https://github.com/skyportsh/depot/tree/master/java/17j9)
  - `ghcr.io/skyportsh/images:java_17j9`
- [`java/18`](https://github.com/skyportsh/depot/tree/master/java/18)
  - `ghcr.io/skyportsh/images:java_18`
- [`java/18j9`](https://github.com/skyportsh/depot/tree/master/java/18j9)
  - `ghcr.io/skyportsh/images:java_18j9`
- [`java/19`](https://github.com/skyportsh/depot/tree/master/java/19)
  - `ghcr.io/skyportsh/images:java_19`
- [`java/19j9`](https://github.com/skyportsh/depot/tree/master/java/19j9)
  - `ghcr.io/skyportsh/images:java_19j9`
- [`java/21`](https://github.com/skyportsh/depot/tree/master/java/21)
  - `ghcr.io/skyportsh/images:java_21`
- [`java/25`](https://github.com/skyportsh/depot/tree/master/java/25)
  - `ghcr.io/skyportsh/images:java_25`

### Node.js images

- [`nodejs/12`](https://github.com/skyportsh/depot/tree/master/nodejs/12)
  - `ghcr.io/skyportsh/images:nodejs_12`
- [`nodejs/14`](https://github.com/skyportsh/depot/tree/master/nodejs/14)
  - `ghcr.io/skyportsh/images:nodejs_14`
- [`nodejs/15`](https://github.com/skyportsh/depot/tree/master/nodejs/15)
  - `ghcr.io/skyportsh/images:nodejs_15`
- [`nodejs/16`](https://github.com/skyportsh/depot/tree/master/nodejs/16)
  - `ghcr.io/skyportsh/images:nodejs_16`
- [`nodejs/17`](https://github.com/skyportsh/depot/tree/master/nodejs/17)
  - `ghcr.io/skyportsh/images:nodejs_17`
- [`nodejs/18`](https://github.com/skyportsh/depot/tree/master/nodejs/18)
  - `ghcr.io/skyportsh/images:nodejs_18`
- [`nodejs/20`](https://github.com/skyportsh/depot/tree/master/nodejs/20)
  - `ghcr.io/skyportsh/images:nodejs_20`

### Python images

- [`python/3.7`](https://github.com/skyportsh/depot/tree/master/python/3.7)
  - `ghcr.io/skyportsh/images:python_3.7`
- [`python/3.8`](https://github.com/skyportsh/depot/tree/master/python/3.8)
  - `ghcr.io/skyportsh/images:python_3.8`
- [`python/3.9`](https://github.com/skyportsh/depot/tree/master/python/3.9)
  - `ghcr.io/skyportsh/images:python_3.9`
- [`python/3.10`](https://github.com/skyportsh/depot/tree/master/python/3.10)
  - `ghcr.io/skyportsh/images:python_3.10`
- [`python/3.11`](https://github.com/skyportsh/depot/tree/master/python/3.11)
  - `ghcr.io/skyportsh/images:python_3.11`

### Installer images

- [`installers/alpine`](https://github.com/skyportsh/depot/tree/master/installers/alpine)
  - `ghcr.io/skyportsh/installers:alpine`
- [`installers/debian`](https://github.com/skyportsh/depot/tree/master/installers/debian)
  - `ghcr.io/skyportsh/installers:debian`

## Contributing

When adding a new image variant, place it in the matching directory and update the corresponding workflow in
`.github/workflows` so the correct tag is published.
