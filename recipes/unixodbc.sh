# shellcheck shell=sh disable=SC2154 # work, prefix, and jobs are set by build.sh
# Recipe of the unixODBC artifact for scripts/build.sh: the ODBC
# driver manager (libodbc) and its installer library (libodbcinst), which an
# ODBC driver links, as shared libraries that find each other beside
# themselves. GNU ltdl is built in from unixODBC's own copy; readline, which
# only the command-line tools use, is left out.
#
# The configuration directory built in is the system's /etc, where unixODBC
# looks by convention, and not a path of this build: settings such as tracing
# in the system's odbcinst.ini apply as they do to any unixODBC. The drivers it
# registers are not used, since a connector names its driver by path. The
# files `make install` would put there go to the artifact instead.

(
	cd "$work/unixODBC" || exit
	./configure \
		--prefix="$prefix" \
		--sysconfdir=/etc \
		--disable-static \
		--disable-readline \
		--with-included-ltdl
	make -j "$jobs"
	make install sysconfdir="$prefix/etc"
)

# The manylinux image's patchelf sets the search path, which libtool would
# otherwise make an absolute path of this build.
for library in "$prefix"/lib/*.so.*; do
	# shellcheck disable=SC2016 # $ORIGIN is for the dynamic loader
	[ -L "$library" ] || patchelf --set-rpath '$ORIGIN' "$library"
done
# shellcheck disable=SC2016 # $ORIGIN is for the dynamic loader
printf '\nAfter building, the search path of the shared libraries in lib/ was set to\n$ORIGIN with patchelf; they are otherwise as built.\n' >>"$prefix/LICENSES/SOURCES.txt"
