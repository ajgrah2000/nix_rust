{
  description = "Multi-target Rust build (native, Windows, Emscripten) with shared toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    rust-nightly.url = "path:./../rust_nightly";

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

        # Shared cargo dirs for reproducibility
        cargoEnv = {
          CARGO_TARGET_DIR = "${placeholder "out"}/cargo-target";
          CARGO_HOME       = "${placeholder "out"}/cargo-home";
        };

        # Shared Rust inputs for all targets
        commonInputs = [
          toolchain
          pkgs.SDL2
        ];

        # Helper to build Rust packages
        mkRustBuild = {
          name,
          version,
          src,
          cargoHash,
          buildInputs,
          extraEnv ? {},
          buildPhase
        }:
          pkgs.stdenv.mkDerivation (
            {
              inherit name version src buildInputs cargoHash;
            }
            // cargoEnv
            // extraEnv
            // {
              buildPhase = ''
                cd $src
                mkdir -p "$CARGO_HOME" "$CARGO_TARGET_DIR"
                ${buildPhase}
              '';
            }
          );

      in
      {
        packages = {
          native = mkRustBuild {
            cargoHash = "";
            name = "rust_rustsega";
            version = "0.0.1-native";
            src = rustsega;

            buildInputs = commonInputs;

            buildPhase = ''
              cargo build --release
            '';
          };

          windows = mkRustBuild {
            cargoHash = "";
            name = "rust_rustsega";
            version = "0.0.1-windows";
            src = rustsega;
          
            buildInputs = commonInputs ++ [
              pkgs.pkgsCross.mingwW64.stdenv.cc
              pkgs.pkgsCross.mingwW64.SDL2
              pkgs.pkgsCross.mingwW64.sdl3
              pkgs.pkgsCross.mingwW64.windows.pthreads
            ];
          
            extraEnv = {
              CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
              RUSTFLAGS =
                "-L native=${pkgs.pkgsCross.mingwW64.SDL2}/lib " +
                "-L native=${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib";
            };
          
            # For the current package versions of nix both 'SDL2.dll' and 'SDL3.dll' is needed.
            buildPhase = ''
              cargo build --release
              cp ${pkgs.pkgsCross.mingwW64.SDL2.dev}/bin/SDL2.dll \
                 $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/
              cp ${pkgs.pkgsCross.mingwW64.sdl3.out}/bin/SDL3.dll \
                 $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/
            '';
          };

          emscripten = mkRustBuild {
            cargoHash = "";
            name = "rust_rustsega";
            version = "0.0.1-emscripten";
            src = rustsega;

            buildInputs = commonInputs ++ [
              pkgs.emscripten
            ];

            buildPhase = ''
              cd projects/emscripten
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

