#!/bin/sh
# Prints the dependency whose release a tag names, as
# <dependency>-<version>[-r<revision>] by its current entry in
# dependencies.json; fails if no dependency's release has that tag. The
# release workflow uses it to find what a pushed tag publishes.
#
# Usage: scripts/dependency.sh <tag>
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
tag=${1:?usage: scripts/dependency.sh <tag>}
dependency=
# shellcheck source=scripts/common.sh
. "$root/scripts/common.sh"

for dependency in $(jq -r '.dependencies | keys[]' "$declaration"); do
	if [ "$(release_tag)" = "$tag" ]; then
		echo "$dependency"
		exit 0
	fi
done
echo "no dependency of dependencies.json is released as $tag" >&2
exit 1
