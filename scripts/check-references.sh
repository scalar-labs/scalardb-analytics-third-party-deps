#!/bin/sh
# Prints every reference of the given binaries that points outside the system
# and a given lib directory, one per line; prints nothing when there is none.
#
# A binary may load only system libraries and the libraries in the lib
# directory, may search for them only relative to itself, and is named either
# relative to its search path or without a path; on Linux, no glibc symbol is
# newer than the 2.28 baseline. scripts/build.sh runs it on an artifact's
# libraries against the artifact's lib/. It is the check ScalarDB Analytics
# connectors run on their packages, so an artifact passes where it ships.
#
# Usage: scripts/check-references.sh <lib directory> <binary>...
set -eu

lib=${1:?usage: check-references.sh <lib directory> <binary>...}
shift

# Whether a library of this file name is in the lib directory.
shipped() { [ -f "$lib/$1" ]; }
case "$(uname -s)" in
Darwin)
	for binary; do
		# A library's own install name is listed among its references. A name
		# without a path, as an ADBC driver that is only loaded by its path may
		# carry, points nowhere outside the package.
		id=$(otool -D "$binary" | tail -n 1)
		case "$id" in
		@rpath/*) ;;
		*/*) echo "$binary is named $id" ;;
		esac
		otool -L "$binary" | tail -n +2 | awk '{ print $1 }' | while read -r reference; do
			case "$reference" in
			/usr/lib/* | /System/Library/*) ;;
			"$id") ;;
			@rpath/*) shipped "${reference#@rpath/}" || echo "$binary references $reference" ;;
			*) echo "$binary references $reference" ;;
			esac
		done
		otool -l "$binary" | awk '/cmd LC_RPATH/ { getline; getline; print $2 }' | while read -r rpath; do
			case "$rpath" in
			@loader_path | @loader_path/*) ;;
			*) echo "$binary searches $rpath" ;;
			esac
		done
	done
	;;
Linux)
	for binary; do
		readelf -d "$binary" | awk '/\(NEEDED\)/ { gsub(/[][]/, "", $5); print $5 }' | while read -r needed; do
			case "$needed" in
			libc.so.6 | libm.so.6 | libdl.so.2 | libpthread.so.0 | librt.so.1 | libresolv.so.2 | libgcc_s.so.1 | libstdc++.so.6 | ld-linux-*.so.*) ;;
			*) shipped "$needed" || echo "$binary needs $needed" ;;
			esac
		done
		readelf -d "$binary" | awk '/\((RPATH|RUNPATH)\)/ { gsub(/[][]/, "", $5); print $5 }' | tr ':' '\n' | while read -r rpath; do
			case "$rpath" in
			'$ORIGIN' | '$ORIGIN'/*) ;;
			*) echo "$binary searches $rpath" ;;
			esac
		done
		objdump -T "$binary" | grep -o 'GLIBC_[0-9.]*' | sort -u -V | while read -r symbol; do
			newest=$(printf '%s\nGLIBC_2.28\n' "$symbol" | sort -V | tail -n 1)
			[ "$newest" = GLIBC_2.28 ] || echo "$binary uses $symbol"
		done
	done
	;;
esac
