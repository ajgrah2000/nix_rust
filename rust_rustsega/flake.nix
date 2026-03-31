{
  description = "Multi-target Rust build (native, Windows, Emscripten)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    rust-nightly = {
      url = "path:../rust_nightly";
      flake = true;
    };

    rustsega = {
      type = "github";
      owner = "ajgrah2000";
      repo = "rustsega";
      ref = "minor_build_refresh";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-nightly, rustsega }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        repoName = self.name or "rust_rustsega";

        toolchain = rust-nightly.packages.${system}.rustToolchain;
        platform = rust-nightly.packages.${system}.rustPlatform;

        commonInputs = [ toolchain pkgs.SDL2 ];

        mkRustBuild = { pname, version, nativeBuildInputs ? [], buildInputs, buildPhase, checkPhase, installPhase, extraEnv ? {} }:
          platform.buildRustPackage (
            {
              inherit pname version buildInputs nativeBuildInputs;
              src = rustsega;
              CARGO_TARGET_DIR = "${placeholder "out"}/cargo-target-${pname}";
              CARGO_HOME = "${placeholder "out"}/cargo-home-${pname}";
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
              cargoLock = { lockFile = rustsega + "/Cargo.lock"; };
              cargoHash = "sha256-yV0cH7hHsVPkHDiBBOWm9zRr0M5l4Fjfkp4dkmzzbsQ=";
            }
            // extraEnv
          );
      in
      {
        packages = {
          native = mkRustBuild {
            pname = "${repoName}-native";
            version = "0.0.1-native";
            buildInputs = commonInputs;
            buildPhase = ''
              export CARGO_BUILD_TARGET="x86_64-unknown-linux-gnu"
              cargo build --offline --release --target=$CARGO_BUILD_TARGET --config $NIX_BUILD_TOP/.cargo/config.toml
            '';
            checkPhase = "";
            installPhase = "";
          };

          windows = mkRustBuild {
            pname = "${repoName}-windows";
            version = "0.0.1-windows";
            checkPhase = "";
            buildInputs = commonInputs ++ [
              pkgs.pkgsCross.mingwW64.stdenv.cc
              pkgs.pkgsCross.mingwW64.SDL2
              pkgs.pkgsCross.mingwW64.sdl3
              pkgs.pkgsCross.mingwW64.windows.pthreads
            ];
            buildPhase = ''
              export CARGO_BUILD_TARGET="x86_64-pc-windows-gnu"
              export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/x86_64-w64-mingw32-gcc"
              export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="-L native=${pkgs.pkgsCross.mingwW64.SDL2}/lib -L native=${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib"
              cargo build --offline --release --target=$CARGO_BUILD_TARGET --config $NIX_BUILD_TOP/.cargo/config.toml
            '';
            installPhase = ''
              mkdir -p $out/$CARGO_BUILD_TARGET/${repoName}/bin
              cp ${pkgs.pkgsCross.mingwW64.SDL2.dev}/bin/SDL2.dll $out/$CARGO_BUILD_TARGET/${repoName}/bin
              cp ${pkgs.pkgsCross.mingwW64.sdl3.out}/bin/SDL3.dll $out/$CARGO_BUILD_TARGET/${repoName}/bin
              cp $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/rustsega.exe $out/$CARGO_BUILD_TARGET/${repoName}/bin/
            '';
          };

          emscripten = mkRustBuild {
            pname = "${repoName}-emscripten";
            version = "0.0.1-emscripten";
            checkPhase = "";
            nativeBuildInputs = [ pkgs.emscripten ];
            buildInputs = commonInputs ++ [ pkgs.emscripten ];
            buildPhase = ''
              export CARGO_BUILD_TARGET="wasm32-unknown-emscripten"
              export CARGO_TARGET_WASM32_UNKNOWN_EMSCRIPTEN_LINKER="${pkgs.emscripten}/bin/emcc"
              export EMSCRIPTEN_NO_PORTS="1"
              export EM_CACHE="$NIX_BUILD_TOP/emscripten-cache"
              cd projects/emscripten
              cargo build --offline --release --target=$CARGO_BUILD_TARGET --config $NIX_BUILD_TOP/.cargo/config.toml
            '';
            installPhase = ''
              mkdir -p $out/website/${repoName}/target/$CARGO_BUILD_TARGET/release/
              cp $src/index.html $out/website/${repoName}/
              cp $src/file_drop.js $out/website/${repoName}/
              cp $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/*.wasm $out/website/${repoName}/target/$CARGO_BUILD_TARGET/release/
              cp $CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/*.js $out/website/${repoName}/target/$CARGO_BUILD_TARGET/release/
            '';
          };

          default = pkgs.symlinkJoin {
            name = "all-targets";
            paths = [
              self.packages.${system}.native
              self.packages.${system}.windows
              self.packages.${system}.emscripten
            ];
          };
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
