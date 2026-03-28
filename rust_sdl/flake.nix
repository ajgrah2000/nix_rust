{
  description = "Second flake that uses the shared Rust toolchain (works with 'nix develop' but not 'nix shell')";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    rust-nightly.url = "path:../rust_nightly";
  };

  outputs = { self, nixpkgs, flake-utils, rust-nightly }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        toolchain = rust-nightly.packages.${system}.rustToolchain;

      in
      {
        packages.default = pkgs.mkShell {
          buildInputs = [ 
            toolchain 
            pkgs.SDL2
          ];
        };
      }
    );
}

