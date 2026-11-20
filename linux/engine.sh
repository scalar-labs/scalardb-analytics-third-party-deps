# shellcheck shell=sh disable=SC2034 # image and platform are read by the sourcing script
# Sourced by linux/build.sh: checks that the Docker engine runs Linux
# containers and sets, for the engine's own architecture, the pinned
# manylinux_2_28 `image` and the `platform`. Artifacts are built on their own
# architecture, without emulation. The images are those ScalarDB Analytics
# connectors build their Linux packages in.

engine_os=$(docker info --format '{{.OSType}}')
[ "$engine_os" = linux ] || { echo "the Docker engine runs $engine_os containers, not linux" >&2; exit 1; }
engine_arch=$(docker info --format '{{.Architecture}}')
case "$engine_arch" in
x86_64)
	image=quay.io/pypa/manylinux_2_28_x86_64@sha256:d086f64cddcace250ef0f0073583c51b8298159303290a730c9f59bd91edfd2c
	platform=linux_amd64
	;;
aarch64)
	image=quay.io/pypa/manylinux_2_28_aarch64@sha256:34a5e614a4eb26f73f8bf44cbbf2acf8011620453d03ea35a58537bb3cde44de
	platform=linux_arm64
	;;
*) echo "no manylinux image is pinned for the Docker engine's architecture $engine_arch" >&2; exit 1 ;;
esac
