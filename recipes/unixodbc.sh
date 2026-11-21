# shellcheck shell=sh disable=SC2154 # work, prefix, and jobs are set by build.sh
# Recipe of the unixODBC artifact for scripts/build.sh: the ODBC
# driver manager (libodbc) and its installer library (libodbcinst), which an
# ODBC driver links, as shared libraries that find each other beside
# themselves ($ORIGIN, set when they are linked). GNU ltdl is built in from
# unixODBC's own copy; readline, which only the command-line tools use, is
# left out.
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
		--with-included-ltdl \
		LDFLAGS='-Wl,-rpath,\$$ORIGIN'
	make -j "$jobs"
	make install sysconfdir="$prefix/etc"
)

# The cursor library is left out: libodbc loads it only for an application
# that asks for ODBC's cursor emulation, and libtool builds it with the
# absolute library path of this build as its search path, which the build
# reference check rejects.
rm -f "$prefix"/lib/libodbccr.*
printf '\nThe cursor library (libodbccr), an optional part of unixODBC, is not included.\n' >>"$prefix/LICENSES/SOURCES.txt"
