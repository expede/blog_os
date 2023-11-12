{
  description = "blog_os";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {inherit system overlays;};

        rust-toolchain =
          (pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml).override {
            extensions = [
              "cargo"
              "clippy"
              "llvm-tools-preview"
              "rustfmt"
              "rust-src"
              "rust-std"
            ];
          };

        nightly-rustfmt = pkgs.rust-bin.nightly.latest.rustfmt;

        format-pkgs = [
          pkgs.nixpkgs-fmt
          pkgs.alejandra
        ];

        cargo-installs = [
          pkgs.llvmPackages.bintools
          pkgs.cargo-bootimage
          pkgs.cargo-deny
          pkgs.cargo-expand
          pkgs.cargo-outdated
          pkgs.cargo-sort
          pkgs.cargo-udeps
          pkgs.cargo-watch
        ];

      in rec {
        devShells.default = pkgs.mkShell {
          name = "blog_os";
          nativeBuildInputs =
            [
              # The ordering of these two items is important. For nightly rustfmt to be used instead of
              # the rustfmt provided by `rust-toolchain`, it must appear first in the list. This is
              # because native build inputs are added to $PATH in the order they're listed here.
              nightly-rustfmt

              rust-toolchain
              pkgs.qemu
              self.packages.${system}.irust
            ]
            ++ format-pkgs
            ++ cargo-installs
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.Security
              pkgs.darwin.apple_sdk.frameworks.CoreFoundation
              pkgs.darwin.apple_sdk.frameworks.Foundation
            ];
        };

        commands = [
          {
            name = "build";
            category = "development";
            command = ''
              ${pkgs.nodejs_18}/bin/node
            '';
          }
        ];

        packages.irust = pkgs.rustPlatform.buildRustPackage rec {
          pname = "irust";
          version = "1.65.1";
          src = pkgs.fetchFromGitHub {
            owner = "sigmaSd";
            repo = "IRust";
            rev = "v${version}";
            sha256 = "sha256-AMOND5q1XzNhN5smVJp+2sGl/OqbxkGPGuPBCE48Hik=";
          };

          doCheck = false;
          cargoSha256 = "sha256-A24O3p85mCRVZfDyyjQcQosj/4COGNnqiQK2a7nCP6I=";
        };
    });
}
