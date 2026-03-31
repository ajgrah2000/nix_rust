{
  description = "Multi-project Nix build for Rust Sega and Atari targets";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    rust_rustsega = {
      url = "path:./rust_rustsega";
      flake = true;
    };

    rust_rusted_atari2600 = {
      url = "path:./rust_rusted_atari2600";
      flake = true;
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust_rustsega, rust_rusted_atari2600 }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    flake-utils.lib.eachDefaultSystem (system:
      {
        packages = {
          rustsega-emscripten = rust_rustsega.packages.${system}.emscripten;
          rustsega-windows = rust_rustsega.packages.${system}.windows;
          rusted_atari2600-emscripten = rust_rusted_atari2600.packages.${system}.emscripten;
          rusted_atari2600-windows = rust_rusted_atari2600.packages.${system}.windows;

          all = pkgs.symlinkJoin {
            name = "all-builds";
            paths = [
              self.packages.${system}.rustsega-emscripten
              self.packages.${system}.rustsega-windows
              self.packages.${system}.rusted_atari2600-emscripten
              self.packages.${system}.rusted_atari2600-windows
            ];
          };

          default = self.packages.${system}.all;
        };
      }
    );
}
