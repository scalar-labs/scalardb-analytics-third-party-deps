#!/bin/sh
# Builds the Linux artifact of a dependency with Docker, as CI does:
# scripts/build.sh runs in the manylinux_2_28 image that linux/engine.sh pins,
# with the repository mounted, so that the libraries need no glibc newer than
# 2.28. The artifact is for the Docker engine's own architecture; the other is
# built on its own host, without emulation.
#
# Usage: linux/build.sh <dependency>
#
# The artifact lands in target/, as scripts/build.sh writes it.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
dependency=${1:?usage: linux/build.sh <dependency>}
# shellcheck source=linux/engine.sh
. "$root/linux/engine.sh"

# The image provides GCC from gcc-toolset, CMake, make, Perl, and patchelf; jq
# reads the declaration, and OpenSSL's Configure needs the Perl modules below.
exec docker run --rm -v "$root:/src" -w /src "$image" sh -c '
	dnf install -y -q jq openssl perl-IPC-Cmd perl-Time-Piece &&
	exec scripts/build.sh "$1"' sh "$dependency"
