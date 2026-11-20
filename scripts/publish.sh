#!/bin/sh
# Publishes the artifacts of a dependency as the release of its tag,
# <dependency>-<version>[-r<revision>], which must already be pushed at the
# commit whose recipe built them; the release workflow runs it when the tag is
# pushed. It takes a directory holding the artifact of every platform the
# dependency lists (scripts/build.sh writes them to target/). The release also
# holds each upstream source the artifacts were built from, so that the
# sources are available where the binaries are, and SHA256SUMS, the SHA-256
# of every artifact and source in the format of `sha256sum -c`; the source
# archive GitHub attaches to the tag holds the recipes. It is a prerelease and
# never the latest release, and an existing release is never replaced.
#
# It prints the artifacts' hashes as SRI, which a consumer declares to pin
# them.
#
# Usage: scripts/publish.sh <dependency> <artifact directory>
#
# Requires gh with permission to create releases, curl, jq, and openssl.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
usage="usage: scripts/publish.sh <dependency> <artifact directory>"
dependency=${1:?$usage}
artifacts=${2:?$usage}
# shellcheck source=scripts/common.sh
. "$root/scripts/common.sh"
field '' >/dev/null || { echo "dependencies.json declares no $dependency" >&2; exit 1; }
tag=$(release_tag)

assets=$(mktemp -d)
trap 'rm -rf "$assets"' EXIT
for platform in $(field '.platforms[]'); do
	file=$artifacts/$(artifact_name).tar.gz
	[ -f "$file" ] || { echo "no $platform artifact at $file" >&2; exit 1; }
	cp "$file" "$assets/"
	echo "$(artifact_name): sha256-$(openssl dgst -sha256 -binary "$file" | openssl base64 -A)"
done
count=$(field '.components | length')
index=0
while [ "$index" -lt "$count" ]; do
	url=$(field ".components[$index].url")
	fetch "$url" "$(field ".components[$index].hash")" "$assets/$(basename "$url")"
	index=$((index + 1))
done
for file in "$assets"/*.tar.gz; do
	printf '%s  %s\n' "$(openssl dgst -sha256 -r "$file" | cut -d ' ' -f 1)" "$(basename "$file")"
done >"$assets/SHA256SUMS"

# The notes say what an artifact's LICENSES/SOURCES.txt says, taken from the
# artifact of the first platform, so that the page and the artifacts agree.
platform=$(field '.platforms[0]')
{
	tar -xzOf "$assets/$(artifact_name).tar.gz" "$(artifact_name)/LICENSES/SOURCES.txt"
	printf '\nEach artifact holds the license texts of these components in\n'
	printf 'LICENSES/<component>/, and this text in LICENSES/SOURCES.txt.\n'
} >"$assets/notes"
gh release create "$tag" "$assets"/*.tar.gz "$assets/SHA256SUMS" \
	--repo "$repository" \
	--verify-tag \
	--title "$tag" \
	--notes-file "$assets/notes" \
	--prerelease \
	--latest=false
