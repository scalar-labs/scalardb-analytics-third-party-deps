# shellcheck shell=sh disable=SC2154 # work, prefix, and jobs are set by build.sh
# Recipe of the Kerberos artifact for scripts/build.sh: OpenSSL 3
# and the MIT Kerberos client libraries built against it, as shared libraries
# that find each other beside themselves ($ORIGIN, set when they are linked;
# Kerberos's own search path is turned off). They are what Microsoft ODBC Driver
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
		shared no-tests no-docs \
		'-Wl,-rpath,\$$ORIGIN'
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
		LDFLAGS="-L$prefix/lib "'-Wl,-rpath,\$$ORIGIN'
	make -j "$jobs"
	make install sysconfdir="$prefix/etc" localstatedir="$prefix/var"
)
