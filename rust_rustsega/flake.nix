{
  description = "Second flake that uses the shared Rust toolchain (works with 'nix develop' but not 'nix shell')";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    rust-nightly.url = "path:../rust_nightly";

    rustsega = {
      type = "github";
      owner = "ajgrah2000";
      repo = "rustsega";
      ref = "master";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-nightly, rustsega }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        toolchain = rust-nightly.packages.${system}.rustToolchain;

      in
      {
        packages = {
            native = pkgs.stdenv.mkDerivation {
              pname = "rust_rustsega";
              version = "0.0.1-native";
  
              CARGO_TARGET_DIR = "${placeholder "out"}/cargo-target";
              CARGO_HOME = "${placeholder "out"}/cargo-home";
  
              src = rustsega;
  
              buildInputs = [ 
                toolchain 
                pkgs.SDL2
              ];
  
              buildPhase = ''
                cd $src
                mkdir -p "$CARGO_HOME" "$CARGO_TARGET_DIR"
                cargo build --release
              '';
  
            };
  
            emscripten = pkgs.stdenv.mkDerivation {
              pname = "rust_rustsega";
              version = "0.0.1-emscripten";
  
              CARGO_TARGET_DIR = "${placeholder "out"}/cargo-target";
              CARGO_HOME = "${placeholder "out"}/cargo-home";
  
              src = rustsega;
  
              buildInputs = [ 
                toolchain 
                pkgs.SDL2
              ];
  
              buildPhase = ''
                cd $src/projects/emscripten
                mkdir -p "$CARGO_HOME" "$CARGO_TARGET_DIR"
                cargo build --release
              '';
  
            };

            all = pkgs.symlinkJoin {
              name = "all-targets";
              paths = [
                self.packages.${system}.native
                self.packages.${system}.emscripten
              ];
            };
  
           default = self.packages.${system}.all;
        };
    }
    );

}

