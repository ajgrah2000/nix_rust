{
  description = "Multi-target Rust build (native, Windows, Emscripten) with shared toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    rust-nightly = {
      url = "path:../rust_nightly";
      flake = false;
    };

    rusted_atari2600 = {
      type = "github";
      owner = "ajgrah2000";
      repo = "rusted_atari2600";
      ref = "master";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-nightly, rusted_atari2600 }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        toolchain = rust-nightly.packages.${system}.rustToolchain;
        platform = rust-nightly.packages.${system}.rustPlatform;

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
          checkPhase,
          installPhase ,
          buildInputs,
          extraEnv ? {},
          buildPhase
        }:
          let
          cargoEnv = {
            CARGO_TARGET_DIR = "${placeholder "out"}/cargo-target-${pname}";
            CARGO_HOME       = "${placeholder "out"}/cargo-home-${pname}";
          };

          in
          platform.buildRustPackage (
            {
              inherit pname version buildInputs;
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

              # All targets use the same source/cargo lock.
              src = rusted_atari2600;

              cargoLock = {
                lockFile = rusted_atari2600 + "/Cargo.lock";
              };
          
              cargoHash = "sha256-yV0cH7hHsVPkHDiBBOWm9zRr0M5l4Fjfkp4dkmzzbsQ=";

              }
          );

      in
      {
        packages = {
          native = mkRustBuild {
            pname = "rust_rusted_atari2600-native";
            version = "0.0.1-native";

            buildInputs = commonInputs;

            extraEnv = {
              CARGO_BUILD_TARGET = "x86_64-unknown-linux-gnu";
            };
 
            # Oh my, this can't be right...
            buildPhase = ''
              cargo build --offline --release --target=$CARGO_BUILD_TARGET --config $NIX_BUILD_TOP/.cargo/config.toml
            '';

            # Need to disable checks, until the source repo is fixed.
            checkPhase = "";
 
            # Currently no install for 'native', would need to package dependencies for it to work.
            installPhase = ''
            '';
          };

          windows = mkRustBuild {
            pname = "rust_rusted_atari2600-windows";
            version = "0.0.1-windows";

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
              cargo build --offline --release --target=$CARGO_BUILD_TARGET --config $NIX_BUILD_TOP/.cargo/config.toml
              '';

            installPhase = ''
               mkdir -p $out/$CARGO_BUILD_TARGET/bin
               cp $src/palette_*.dat $out/$CARGO_BUILD_TARGET/bin
               cp ${pkgs.pkgsCross.mingwW64.SDL2.dev}/bin/SDL2.dll $out/$CARGO_BUILD_TARGET/bin
               cp ${pkgs.pkgsCross.mingwW64.sdl3.out}/bin/SDL3.dll $out/$CARGO_BUILD_TARGET/bin
               cp $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/rusted_atari2600.exe $out/$CARGO_BUILD_TARGET/bin/
             '';
          };

          emscripten = mkRustBuild {
            pname = "rust_rusted_atari2600-emscripten";
            version = "0.0.1-emscripten";

            checkPhase = "";
          
            extraEnv = {
              CARGO_BUILD_TARGET = "wasm32-unknown-emscripten";
              CARGO_TARGET_WASM32_UNKNOWN_EMSCRIPTEN_LINKER = "${pkgs.emscripten}/bin/emcc";
              EMSCRIPTEN_NO_PORTS = "1";
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
              cargo build --offline --release --target=$CARGO_BUILD_TARGET --config $NIX_BUILD_TOP/.cargo/config.toml
            '';
            installPhase = ''
              mkdir -p $out/website/target/$CARGO_BUILD_TARGET/release/
              cp $src/index.html $out/website/
              cp $src/file_drop.js $out/website/
              cp $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/*.wasm $out/website/target/$CARGO_BUILD_TARGET/release/
              cp $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/*.js $out/website/target/$CARGO_BUILD_TARGET/release/
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

