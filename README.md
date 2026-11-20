# ScalarDB Analytics third-party dependencies

Prebuilt binaries of the third-party libraries ScalarDB Analytics needs whose
upstreams distribute only source code, built here from those upstream sources
and published as GitHub Releases together with the sources.

ScalarDB Analytics uses a library's official prebuilt binaries when its
upstream publishes them (DuckDB's static libraries, ADBC drivers' wheels).
Third-party builds, such as distribution packages or conda-forge, are not
used. A library available only as source code is built once here, when its
version or its build changes, so that no build pipeline of ScalarDB Analytics
builds it: a consumer fetches the artifact and checks it against the hash it
declares.

## Dependencies

`dependencies.json` declares each dependency: its `name`, `version` (that of
its main component), optional `revision`, the `platforms` it is built for, and
its `components`, the upstream sources built into it, each with `name`,
`version`, `license`, the source archive's `url` and SRI sha256 `hash`, and
`licenses`, the paths of its license texts in the source.

| Dependency | Components | Platforms | Recipe |
| --- | --- | --- | --- |
| `protobuf` | abseil, protobuf | osx_arm64, linux_amd64, linux_arm64 | Static, position-independent libraries for C++17, with protoc; without zlib |
| `unixodbc` | unixODBC | linux_amd64, linux_arm64 | The shared driver manager libraries (libodbc, libodbcinst), with GNU ltdl built in |
| `kerberos` | OpenSSL 3, MIT Kerberos | linux_amd64, linux_arm64 | The shared libraries of OpenSSL and of the Kerberos client, without keyutils, LDAP, or PKINIT |

Platforms use DuckDB's names. The sources are not modified. The Linux shared
libraries' search path is set to `$ORIGIN` with patchelf after they are built.

## Artifacts

A release is tagged `<dependency>-<version>[-r<revision>]` and holds:

- the artifact of each platform, `<tag>-<platform>.tar.gz`;
- the upstream source archive of each component, as published by its
  upstream.

The recipes that built the artifacts are in the source archive GitHub
attaches to the tag. A release is a prerelease and never the latest release;
an existing release is never replaced.

An artifact holds one directory, `<tag>-<platform>/`, which is an
installation prefix:

| Path | Contents |
| --- | --- |
| `include/`, `lib/`, `lib/cmake/`, `bin/` | What the components install |
| `LICENSES/<component>/` | The license texts of each component |
| `LICENSES/SOURCES.txt` | The sources the artifact was built from, and the release that holds them |

A shared library in `lib/` references only the system and the other
libraries in `lib/`, and finds them beside itself (`$ORIGIN`,
`@loader_path`); on Linux it needs no glibc newer than 2.28
(`scripts/check-references.sh`, which the build runs). Linux artifacts are
built in the manylinux_2_28 image that ScalarDB Analytics connectors build
their Linux packages in, and macOS artifacts with the same nixpkgs toolchain
as their macOS packages.

## Releasing a dependency

1. Edit its entry in `dependencies.json`: for a new upstream version, the
   components' versions, URLs, and hashes and `version`; for a new build of
   the same version, such as a changed recipe or image, raise `revision`
   (absent means none).
2. Build and check it locally (below), then commit.
3. Push the tag `<dependency>-<version>[-r<revision>]` at that commit. The
   Release workflow (`.github/workflows/release.yml`) builds the artifact on
   each platform listed and publishes the tag's release. Its publish step
   prints the artifacts' hashes.
4. Declare the release and the hashes in the consumer, such as
   `packaging/dependencies.json` of ScalarDB Analytics connectors.

## Security updates

A consumer that ships these libraries, such as the ScalarDB Analytics
connectors package, receives their security fixes only through this
repository: a system's package manager does not update them. When an upstream
publishes a security release that affects a dependency, especially OpenSSL or
MIT Kerberos, release the fixed version here (Releasing a dependency) and
update the consumers' declarations so that they ship it.

## Linux baseline

Linux artifacts are built in the manylinux_2_28 image, so they need glibc 2.28
or newer: glibc runs binaries built against an older version, but not the
reverse. The baseline is the oldest major distribution still under vendor
support, RHEL 8. It is revisited when the image is no longer maintained.

## Building locally

| Platform | Command | Requires |
| --- | --- | --- |
| Linux | `linux/build.sh <dependency>` | Docker; the artifact is for the Docker engine's architecture |
| macOS | `nix develop --command scripts/build.sh <dependency>` | Nix |

The artifact lands in `target/`, and the build prints its hash. A local build
differs from the published artifact byte for byte, so a consumer pins the
published one.

## Files

| File | Role |
| --- | --- |
| `dependencies.json` | The dependencies and the upstream sources they are built from |
| `scripts/build.sh` | Builds a dependency's artifact for the running platform with its recipe |
| `recipes/<dependency>.sh` | How a dependency's components are built and installed |
| `scripts/check-references.sh` | Checks that libraries reference only the system and a lib directory |
| `scripts/publish.sh` | Publishes a dependency's artifacts and sources as the release of its tag |
| `scripts/dependency.sh` | Names the dependency whose release a tag is |
| `scripts/common.sh` | The running platform, reading the declaration, fetching with a hash check, and release names |
| `linux/build.sh`, `linux/engine.sh` | Run `scripts/build.sh` in the pinned manylinux_2_28 image |
| `flake.nix` | The macOS build shell |

## License

The files of this repository are under the Apache License 2.0 (`LICENSE`).
Each dependency is under its own license, whose texts each artifact holds.
