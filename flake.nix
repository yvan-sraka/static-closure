# This is an experiment around the idea of statically evaluating and cache a
# closure to reduce overall bootstrap time latency and artifacts download size
# of a given developer shell.
#
# The whole thing could be seen as a binary/build cache, but rather at
# closure-level than at derivation-level.

{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    with builtins;
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        url = "https://s3.zw3rk.com/devx/";
        closure = name:
          pkgs.runCommand "import-closure" { } ''
            ${pkgs.zstd}/bin/zstd -d ${closure-zstd name} -o $out
            ${pkgs.nix}/bin/nix-store --import < $out
          '';
        closure-zstd = name: fetchurl "${url}${system}.${name}.zstd";
        dev-env = name: fetchurl "${url}${system}.${name}.sh";
      in {
        devShells = listToAttrs (map (name: {
          inherit name;
          value = pkgs.mkShell {
            shellHook = ''
              echo "Bootstrapped from: ${closure name}"
              source ${dev-env name}
            '';
          };
        }) [
          "ghc8107"
          "ghc902"
          "ghc925"
          "ghc8107-minimal"
          "ghc902-minimal"
          "ghc925-minimal"
          "ghc8107-static-minimal"
          "ghc902-static-minimal"
          "ghc925-static-minimal"
        ]);
      });
  nixConfig.extra-trusted-public-keys = [
    "s3.zw3rk.com:fx41B+c2mUAvQt+wgzD0g/SBesJhUiShi0s6dV549Co="
  ];
}
