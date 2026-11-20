{
  description = "The shell that builds the macOS artifacts of scalardb-analytics-third-party-deps";

  # The nixpkgs revision of ScalarDB Analytics connectors, whose packages and
  # development shell link these artifacts with the same toolchain.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/f3a73bcf5d1c5b75a66cf35a48957e30d41d647a";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # What scripts/build.sh and the recipes need beyond macOS itself, which
      # provides curl, openssl, make, and tar.
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShellNoCC {
          name = "scalardb-analytics-third-party-deps";
          packages = [
            pkgs.clang
            pkgs.cmake
            pkgs.jq
          ];
        };
      });
    };
}
