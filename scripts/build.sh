#!/bin/sh
# Builds the artifact of a dependency for the running platform, from the
# upstream sources dependencies.json declares under its `components`:
#
#   target/<dependency>-<version>[-r<revision>]-<platform>.tar.gz
#
# The artifact is an installation prefix (include/, lib/, ...) under a
# top-level directory of the same name, with each component's license texts
# in LICENSES/<component>/ and, in LICENSES/SOURCES.txt, the sources it was
# built from and the release that holds them. The recipe
# recipes/<dependency>.sh builds it. A shared library in its lib/ may
# reference only the system and that lib/ (scripts/check-references.sh).
#
# It runs on Linux in the manylinux_2_28 container that linux/build.sh starts,
# and on macOS in this repository's Nix shell (`nix develop`).
#
# Usage: scripts/build.sh <dependency>
#
# Requires curl, jq, openssl, a C and C++ compiler, make, cmake, and what the
# recipe needs.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
dependency=${1:?usage: scripts/build.sh <dependency>}
# shellcheck source=scripts/common.sh
. "$root/scripts/common.sh"
field '' >/dev/null || { echo "dependencies.json declares no $dependency" >&2; exit 1; }
field '.platforms | index($platform)' >/dev/null || { echo "$dependency is not built for $platform" >&2; exit 1; }

name=$(artifact_name)
output=$root/target
work=$output/build/$name
prefix=$work/$name
rm -rf "$work"
mkdir -p "$work/sources" "$prefix/LICENSES" "$output"
# shellcheck disable=SC2034 # read by the recipe
jobs=$(getconf _NPROCESSORS_ONLN)

# Each component's source, checked against its hash, unpacked into
# $work/<component> without the archive's top-level directory.
count=$(field '.components | length')
index=0
while [ "$index" -lt "$count" ]; do
	component=$(field ".components[$index].name")
	archive=$work/sources/$(basename "$(field ".components[$index].url")")
	fetch "$(field ".components[$index].url")" "$(field ".components[$index].hash")" "$archive"
	mkdir -p "$work/$component" "$prefix/LICENSES/$component"
	tar -C "$work/$component" --strip-components 1 -xzf "$archive"
	for license in $(field ".components[$index].licenses[]"); do
		mkdir -p "$prefix/LICENSES/$component/$(dirname "$license")"
		cp "$work/$component/$license" "$prefix/LICENSES/$component/$license"
	done
	index=$((index + 1))
done
{
	printf '%s %s is built without modification from these upstream sources by\n' "$(field '.name')" "$(field '.version')"
	printf 'recipes/%s.sh at https://github.com/%s/tree/%s.\n' "$dependency" "$repository" "$(release_tag)"
	printf 'Each source archive was obtained from its upstream at the URL below, checked\n'
	printf 'against its SHA-256 hash, and is published as obtained beside the artifact at\n'
	printf 'https://github.com/%s/releases/tag/%s.\n\n' "$repository" "$(release_tag)"
	field '.components[] | "- \(.name) \(.version) (\(.license)), obtained from \(.url)\n  (\(.hash))"'
} >"$prefix/LICENSES/SOURCES.txt"

# The recipe builds from $work/<component> and installs into $prefix, with
# $jobs parallel jobs. A recipe that changes the built binaries afterwards
# says how in $prefix/LICENSES/SOURCES.txt.
# shellcheck source=/dev/null
. "$root/recipes/$dependency.sh"

# The shared libraries, which a package may ship; executables such as protoc
# serve only a build.
# shellcheck disable=SC2046 # the artifact's file names hold no whitespace
references=$("$root/scripts/check-references.sh" "$prefix/lib" \
	$(find "$prefix/lib" -maxdepth 1 -type f -name "*.$suffix*"))
if [ -n "$references" ]; then
	echo "$dependency: the artifact references more than the system and its own lib/:" >&2
	printf '%s\n' "$references" >&2
	exit 1
fi

tar -C "$work" -czf "$output/$name.tar.gz" "$name"
echo "$output/$name.tar.gz"
echo "$name: sha256-$(openssl dgst -sha256 -binary "$output/$name.tar.gz" | openssl base64 -A)"
