# This is an experiment around the idea of statically evaluating and cache a
# closure to reduce overall bootstrap time latency and artifacts download size
# of a given developer shell.
#
# The whole thing could be seen as a binary/build cache, but rather at
# closure-level than at derivation-level.

{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        setup-minio-client = ''
          # Overriding $HOME in a derivation is indeed a hack ...
          export HOME=$(mktemp -d)
          ${pkgs.minio-client}/bin/mc alias set zw3rk https://s3.zw3rk.com/ "" ""
          # ... and we should rather rely on so Nix builtins (that are currently
          # broken): pkgs.fetchurl { url = "s3://s3.zw3rk.com/..."; };
        '';
        closure = name:
          pkgs.runCommand "download-closure" { } ''
            ${setup-minio-client}
            TMP=$(mktemp)
            ${pkgs.minio-client}/bin/mc cp zw3rk/devx/${system}.${name}.zstd $TMP
            ${pkgs.zstd}/bin/zstd -d $TMP -o $out
          '';
        dev-env = name:
          pkgs.runCommand "download-dev-env" { } ''
            ${setup-minio-client}
            ${pkgs.minio-client}/bin/mc cp zw3rk/devx/${system}.${name}.sh $out
          '';
      in {
        devShells = with builtins;
          listToAttrs (map (name: {
            inherit name;
            value = pkgs.mkShell { shellHook = ''
              sudo nix-store --import < ${closure name}
              source ${dev-env name}
            ''; };
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
}
