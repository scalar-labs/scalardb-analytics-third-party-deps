# shellcheck shell=sh disable=SC2154 # work, prefix, and jobs are set by build.sh
# Recipe of the Kerberos artifact for scripts/build.sh: OpenSSL 3
# and the MIT Kerberos client libraries built against it, as shared libraries
# that find each other beside themselves. They are what Microsoft ODBC Driver
# 18 for SQL Server needs beyond the system: it links libkrb5 and
# libgssapi_krb5, and loads libssl by name.
#
# Only the libraries are used. Kerberos is built without keyutils, LDAP, and
# PKINIT, so it needs nothing beyond OpenSSL and the system.
#
# The configuration directories built in are the system's, as for any OpenSSL
# and Kerberos, and not paths of this build: OpenSSL's /etc/ssl, where it
# finds the trusted certificates and openssl.cnf on Debian, Ubuntu, SUSE, and
# Alpine; Kerberos's /etc, where krb5.conf is. OpenSSL installs no files
# there (install_sw), and the files Kerberos's `make install` would put there
# go to the artifact instead.

(
	cd "$work/openssl" || exit
	./Configure \
		--prefix="$prefix" \
		--libdir=lib \
		--openssldir=/etc/ssl \
		shared no-tests no-docs
	make -j "$jobs"
	make install_sw
)

(
	cd "$work/krb5/src" || exit
	# The programs configure runs link the OpenSSL built above.
	export LD_LIBRARY_PATH="$prefix/lib"
	./configure \
		--prefix="$prefix" \
		--sysconfdir=/etc \
		--localstatedir=/var \
		--disable-static \
		--disable-rpath \
		--disable-pkinit \
		--with-crypto-impl=openssl \
		--with-tls-impl=no \
		--without-keyutils \
		--without-ldap \
		--without-tcl \
		--without-libedit \
		--without-system-verto \
		CPPFLAGS="-I$prefix/include" \
		LDFLAGS="-L$prefix/lib"
	make -j "$jobs"
	make install sysconfdir="$prefix/etc" localstatedir="$prefix/var"
)

# The manylinux image's patchelf sets the search path, which the builds would
# otherwise leave empty or make an absolute path of this build.
for library in "$prefix"/lib/*.so.*; do
	# shellcheck disable=SC2016 # $ORIGIN is for the dynamic loader
	[ -L "$library" ] || patchelf --set-rpath '$ORIGIN' "$library"
done
# shellcheck disable=SC2016 # $ORIGIN is for the dynamic loader
printf '\nAfter building, the search path of the shared libraries in lib/ was set to\n$ORIGIN with patchelf; they are otherwise as built.\n' >>"$prefix/LICENSES/SOURCES.txt"
