# shellcheck shell=sh disable=SC2154 # work, prefix, and jobs are set by build.sh
# Recipe of the unixODBC artifact for scripts/build.sh: the ODBC
# driver manager (libodbc) and its installer library (libodbcinst), which an
# ODBC driver links, as shared libraries that find each other beside
# themselves ($ORIGIN or @loader_path, set when they are linked). GNU ltdl is
# built in from
# unixODBC's own copy; readline, which only the command-line tools use, is
# left out.
#
# The configuration directory built in is the system's /etc, where unixODBC
# looks by convention, and not a path of this build: settings such as tracing
# in the system's odbcinst.ini apply as they do to any unixODBC. The drivers it
# registers are not used, since a connector names its driver by path. The
# files `make install` would put there go to the artifact instead.

case "$platform" in
osx_*) search_path='-Wl,-rpath,@loader_path' ;;
*) search_path='-Wl,-rpath,\$$ORIGIN' ;;
esac
(
	cd "$work/unixODBC" || exit
	./configure \
		--prefix="$prefix" \
		--sysconfdir=/etc \
		--disable-static \
		--disable-readline \
		--with-included-ltdl \
		LDFLAGS="$search_path"
	make -j "$jobs"
	make install sysconfdir="$prefix/etc"
)

# The cursor library is left out: libodbc loads it only for an application
# that asks for ODBC's cursor emulation, and libtool builds it with the
# absolute library path of this build as its search path, which the build
# reference check rejects.
rm -f "$prefix"/lib/libodbccr.*
printf '\nThe cursor library (libodbccr), an optional part of unixODBC, is not included.\n' >>"$prefix/LICENSES/SOURCES.txt"

# On macOS, libtool names each library by its absolute path in this build,
# and the Nix toolchain links its own libiconv, whose ABI the system's has.
# After linking, the libraries are named relative to their search path
# (@rpath, which @loader_path resolves beside themselves), reference each other
# and the system's libiconv by those names, and are signed again ad hoc.
case "$platform" in
osx_*)
	for library in "$prefix"/lib/*.dylib; do
		[ -L "$library" ] && continue
		changes=
		for reference in $(otool -L "$library" | tail -n +2 | awk '{ print $1 }'); do
			case "$reference" in
			"$prefix"/lib/*) changes="$changes -change $reference @rpath/${reference##*/}" ;;
			/nix/store/*/libiconv.2.dylib) changes="$changes -change $reference /usr/lib/libiconv.2.dylib" ;;
			esac
		done
		# shellcheck disable=SC2086 # $changes is a list of options
		install_name_tool -id "@rpath/${library##*/}" $changes "$library"
		codesign --force --sign - "$library"
	done
	printf '\nOn macOS, the libraries are renamed after linking (install_name_tool) to be found\nbeside each other and to load the system'"'"'s libiconv, and signed again ad hoc.\n' >>"$prefix/LICENSES/SOURCES.txt"
	;;
esac
