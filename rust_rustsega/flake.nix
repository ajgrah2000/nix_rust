{
  description = "Multi-target Rust build (native, Windows, Emscripten) with shared toolchain";

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
        platform = rust-nightly.packages.${system}.rustPlatform;

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
          pname,
          nativeBuildInputs ? {},
          version,
          src,
          cargoLock,
          checkPhase,
          installPhase ,
          cargoHash,
          buildInputs,
          extraEnv ? {},
          buildPhase
        }:
          platform.buildRustPackage (
            {
              inherit pname version src buildInputs cargoHash;
            }
            // cargoEnv
            // extraEnv
            // {
              checkPhase = ''
                ${checkPhase}
              '';
              installPhase = ''
                ${installPhase}
              '';
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
            pname = "rust_rustsega";
            version = "0.0.1-native";
          
            src = rustsega;
          
            cargoLock = {
              lockFile = rustsega + "/Cargo.lock";
            };
          
            cargoHash = "sha256-yV0cH7hHsVPkHDiBBOWm9zRr0M5l4Fjfkp4dkmzzbsQ=";
 
            checkPhase = "";
          
            buildInputs = commonInputs;

            extraEnv = {
              CARGO_BUILD_TARGET = "x86_64-unknown-linux-gnu";
            };
 
            buildPhase = ''
              cargo build --release
            '';
 
            # Currently no install for 'native', would need to package dependencies for it to work.
            installPhase = ''
            '';
          };

          windows = mkRustBuild {
            pname = "rust_rustsega";
            version = "0.0.1-windows";

            src = rustsega;

            cargoLock = {
              lockFile = rustsega + "/Cargo.lock";
            };
          
            cargoHash = "sha256-yV0cH7hHsVPkHDiBBOWm9zRr0M5l4Fjfkp4dkmzzbsQ=";

            checkPhase = "";
          
            nativeBuildInputs =  [pkgs.pkgsCross.mingwW64.stdenv.cc];
            buildInputs = commonInputs ++ [
              pkgs.pkgsCross.mingwW64.stdenv.cc
              pkgs.pkgsCross.mingwW64.SDL2
              pkgs.pkgsCross.mingwW64.sdl3
              pkgs.pkgsCross.mingwW64.windows.pthreads
            ];
          
            extraEnv = {
              CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
              CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/x86_64-w64-mingw32-gcc";

              CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS=''
                -L native=${pkgs.pkgsCross.mingwW64.SDL2}/lib
                -L native=${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib
              '';
            };
          
            # For the current package versions of nix both 'SDL2.dll' and 'SDL3.dll' is needed.
            buildPhase = ''
              cargo build --release
              '';
            installPhase = ''
               mkdir -p $out/$CARGO_BUILD_TARGET/bin
               cp ${pkgs.pkgsCross.mingwW64.SDL2.dev}/bin/SDL2.dll $out/$CARGO_BUILD_TARGET/bin
               cp ${pkgs.pkgsCross.mingwW64.sdl3.out}/bin/SDL3.dll $out/$CARGO_BUILD_TARGET/bin
               cp $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/rustsega.exe $out/$CARGO_BUILD_TARGET/bin/
             '';
          };

          emscripten = mkRustBuild {
            pname = "rust_rustsega";
            version = "0.0.1-emscripten";

            src = rustsega;

            cargoLock = {
              lockFile = rustsega + "/Cargo.lock";
            };
          
            cargoHash = "sha256-yV0cH7hHsVPkHDiBBOWm9zRr0M5l4Fjfkp4dkmzzbsQ=";

            checkPhase = "";
          
            extraEnv = {
              CARGO_BUILD_TARGET = "wasm32-unknown-emscripten";
              CARGO_TARGET_WASM32_UNKNOWN_EMSCRIPTEN_LINKER = "${pkgs.emscripten}/bin/emcc";
            };

            nativeBuildInputs = [
              pkgs.emscripten
            ];

            buildInputs = commonInputs ++ [
              pkgs.emscripten
            ];

            buildPhase = ''
              echo em ${pkgs.emscripten}
              cd projects/emscripten
              cargo build --release --target=$CARGO_BUILD_TARGET
            '';
            installPhase = ''
              mkdir -p $out/$CARGO_BUILD_TARGET
              cp $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/*.wasm $out/$CARGO_BUILD_TARGET
              cp $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/*.js $out/$CARGO_BUILD_TARGET
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

