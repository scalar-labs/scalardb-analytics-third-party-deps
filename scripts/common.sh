# shellcheck shell=sh disable=SC2034,SC2154 # sets platform and suffix for, and reads root and dependency of, the sourcing script
# Sourced by the scripts of this repository: the running platform, reading the
# entry of a dependency in dependencies.json, fetching a file checked against
# its hash, and the names of a dependency's release and artifacts.
#
# Sets `platform` (DuckDB's platform names, which ScalarDB Analytics
# packages use), `suffix` (of a shared library), and `declaration`; requires
# `root` to be set to the repository root.

declaration=$root/dependencies.json
repository=scalar-labs/scalardb-analytics-third-party-deps

case "$(uname -s)-$(uname -m)" in
Darwin-arm64) platform=osx_arm64 suffix=dylib ;;
Linux-x86_64) platform=linux_amd64 suffix=so ;;
Linux-aarch64) platform=linux_arm64 suffix=so ;;
*) echo "no platform is defined for $(uname -s) $(uname -m)" >&2; exit 1 ;;
esac

# Reads a field of the entry `$dependency`: field '<jq path below it>'.
field() {
	jq -er --arg dependency "$dependency" --arg platform "$platform" \
		".dependencies[\$dependency]$1" "$declaration"
}

# Downloads a URL to a file and checks it against an SRI sha256 hash.
fetch() {
	curl -fsSL -o "$3" "$1"
	actual=sha256-$(openssl dgst -sha256 -binary "$3" | openssl base64 -A)
	[ "$actual" = "$2" ] || { echo "$dependency: $1 does not match its hash: $actual" >&2; exit 1; }
}

# The tag of the release that holds the artifacts of `$dependency`,
# <dependency>-<version>[-r<revision>], and the base name of its artifact for
# `$platform`, <tag>-<platform>.
release_tag() {
	if field '| has("revision")' >/dev/null; then
		echo "$dependency-$(field '.version')-r$(field '.revision')"
	else
		echo "$dependency-$(field '.version')"
	fi
}
artifact_name() {
	echo "$(release_tag)-$platform"
}
