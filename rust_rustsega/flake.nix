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

        commonInputs = [ 
                toolchain 
                pkgs.SDL2];

      in
      {
        packages = {
            native = pkgs.stdenv.mkDerivation {
              pname = "rust_rustsega";
              version = "0.0.1-native";
  
              CARGO_TARGET_DIR = "${placeholder "out"}/cargo-target";
              CARGO_HOME = "${placeholder "out"}/cargo-home";
  
              src = rustsega;
  
              buildInputs = commonInputs;
  
              buildPhase = ''
                cd $src
                mkdir -p "$CARGO_HOME" "$CARGO_TARGET_DIR"
                cargo build --release
              '';
            };

            windows = pkgs.stdenv.mkDerivation {
              pname = "rust_rustsega";
              version = "0.0.1-windows";
  
              CARGO_TARGET_DIR = "${placeholder "out"}/cargo-target";
              CARGO_HOME = "${placeholder "out"}/cargo-home";
  
              src = rustsega;
  
              buildInputs = [ 
                pkgs.pkgsCross.mingwW64.stdenv.cc
                pkgs.pkgsCross.mingwW64.SDL2
              ] ++ commonInputs;

              CARGO_BUILD_TARGET="x86_64-pc-windows-gnu";
              RUSTFLAGS="-L native=${pkgs.pkgsCross.mingwW64.SDL2}/lib -L native=${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib";
  
              buildPhase = ''
                cd $src
                cargo build --release
                cp ${pkgs.pkgsCross.mingwW64.SDL2.dev}/bin/SDL2.dll $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/
              '';

  
            };
  
            emscripten = pkgs.stdenv.mkDerivation {
              pname = "rust_rustsega";
              version = "0.0.1-emscripten";
  
              CARGO_TARGET_DIR = "${placeholder "out"}/cargo-target";
              CARGO_HOME = "${placeholder "out"}/cargo-home";
  
              src = rustsega;
  
              buildInputs = [ 
                pkgs.emscripten
              ] ++ commonInputs;

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
                self.packages.${system}.windows
                self.packages.${system}.emscripten
              ];
            };
  
           default = self.packages.${system}.all;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            toolchain
            pkgs.pkg-config
            pkgs.openssl
            pkgs.pkgsCross.mingwW64.SDL2
            pkgs.pkgsCross.mingwW64.stdenv.cc
          ];
        };
    }
    );

}

