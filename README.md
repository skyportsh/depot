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

## Tests and publishing

Every image is described in [`images.txt`](images.txt) and **must pass its test profile before it is published**.
The profiles live in [`tests/profiles`](tests/profiles) and check, among other things: the non-root `container` user,
the entrypoint contract (`STARTUP` placeholders, `TZ`, `INTERNAL_IP`, exit codes, no shell injection through variable
values), the runtime version (Java/Node/Go/Python), toolchains, CA certificates, and for games the update and RCON flows.

The optional end-to-end tests (`DEPOT_TEST_E2E=1`, always on in CI) install and start real software the way the panel does:
the catalog's Minecraft install script runs in `installers:debian`, then a real Minecraft server boots on every Java image;
steamcmd is installed and logs in to Steam on the Rust and Source images; Node, Python and Go images install a real
package/module from their registry.

Run them locally (Docker required):

```bash
tests/run.sh                    # build + test everything on the host platform
tests/run.sh java-21 nodejs-20  # only these images (dependencies included)
tests/run.sh --all-platforms    # test every declared platform (QEMU when needed)
tests/run.sh --jobs 4           # test up to 4 independent images in parallel
DEPOT_TEST_E2E=1 tests/run.sh   # also run the end-to-end tests (needs internet)
tests/run.sh --list             # list image ids
```

GitHub Actions (`.github/workflows/images.yml`) runs the same script on every pull request (build + test, no push)
and, on `master`, on a monthly schedule or on manual dispatch (build + test + push). Images are pushed to GHCR only
when all their tests pass, with a floating tag (`java_21`) and an immutable dated tag (`java_21-20261121`).
Every image also has a size budget in `images.txt`; a test run fails when an image grows past it.
Only the images affected by a change are rebuilt on push and pull requests: a change in `go/1.22/` rebuilds `go-1.22`
only, a file shared by a family (`java/entrypoint.sh`) rebuilds that family, a test profile or end-to-end change rebuilds a
sample of the images it covers, and a change to the test framework or the workflow rebuilds one image per profile.
Documentation-only changes rebuild nothing. The monthly run rebuilds everything to pick up base image security updates,
and a manual run can target specific images (`images` input, e.g. `java-21 go-1.22`, empty = everything).

End-of-life runtimes (Node 12-17, Go 1.14-1.17, ...) are kept for compatibility and rebuilt on the latest available
upstream tag, but they no longer receive upstream security fixes.

## Available images

### Base OS images

- [`oses/alpine`](https://github.com/skyportsh/depot/tree/master/oses/alpine)
  - `ghcr.io/skyportsh/images:alpine`
- [`oses/debian`](https://github.com/skyportsh/depot/tree/master/oses/debian)
  - `ghcr.io/skyportsh/images:debian` — lean runtime image (shared libraries and basic tooling)
  - `ghcr.io/skyportsh/images:debian-dev` — the same plus compilers, debuggers, `-dev` headers and ffmpeg

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

JRE-only variants (no `javac`, noticeably smaller) of the LTS versions:

- [`java/8-jre`](https://github.com/skyportsh/depot/tree/master/java/8-jre)
  - `ghcr.io/skyportsh/images:java_8_jre`
- [`java/11-jre`](https://github.com/skyportsh/depot/tree/master/java/11-jre)
  - `ghcr.io/skyportsh/images:java_11_jre`
- [`java/17-jre`](https://github.com/skyportsh/depot/tree/master/java/17-jre)
  - `ghcr.io/skyportsh/images:java_17_jre`
- [`java/21-jre`](https://github.com/skyportsh/depot/tree/master/java/21-jre)
  - `ghcr.io/skyportsh/images:java_21_jre`
- [`java/25-jre`](https://github.com/skyportsh/depot/tree/master/java/25-jre)
  - `ghcr.io/skyportsh/images:java_25_jre`

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
