{
  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-dawn.url = "github:junjihashimoto/nixpkgs?ref=feature/dawn-native";
  };
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-dawn,
    }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      pkgs-dawn = import nixpkgs-dawn { system = "x86_64-linux"; };
      cxxopts_src = pkgs.fetchzip {
        url = "https://github.com/jarro2783/cxxopts/archive/refs/tags/v3.3.1.tar.gz";
        hash = "sha256-baM6EX9D0yfrKxuPXyUUV9RqdrVLyygeG6x57xN8lc4=";
      };
      nlohmann_json_src = pkgs.fetchzip {
        url = "https://github.com/nlohmann/json/releases/download/v3.12.0/json.tar.xz";
        hash = "sha256-tOInM4YYi/cbHCWP2R0jlFzlaTN0ZVgHFMWagz9Wnvk=";
      };
      sentry_native_src = pkgs.fetchFromGitHub {
        owner = "getsentry";
        repo = "sentry-native";
        tag = "0.13.6";
        hash = "sha256-4ZHA/sUHAhYwduLPbFQ3Ju8Pjdz14oiIcSvpFMrbkgE=";
      };

      # TODO this isn't working properly, no way to get this *into* the build
      # because aurora needs dawn and aurora is a submodule, so can't easily
      # modify the aurora cmake
      dawn_src = pkgs.fetchzip {
        url = "https://github.com/encounter/dawn-build/releases/download/v20260423.175430/dawn-linux-x86_64.tar.gz";
        hash = "";
      };

      nod = pkgs.rustPlatform.buildRustPackage rec {
        pname = "nod";
        version = "v2.0.0-alpha.8";

        nativeBuildInputs = [
          pkgs.corrosion
          pkgs.git
        ];

        src = pkgs.fetchFromGitHub {
          owner = "encounter";
          repo = "nod";
          tag = version;
          hash = "sha256-+zrtVzjo0+X/6uMcNUn1+FaSR+jOhrcQSDNBFjw0NDs=";
        };

        cargoHash = "sha256-tRVEireoUnVwra9iFkDrRFK+bB7h4xlnSNByvB9Ao8k=";
      };

      dusk = pkgs.stdenv.mkDerivation {
        name = "dusk";
        src = ./.;
        nativeBuildInputs = [
          pkgs.cmake
          pkgs.pkg-config
          pkgs.wayland
        ];
        buildInputs = [
          nod
          pkgs-dawn.google-dawn
          pkgs.libGL
          pkgs.libX11
          pkgs.libXcursor
          pkgs.libxi
          pkgs.libxcb
          pkgs.libxrandr
          pkgs.libxscrnsaver
          pkgs.libxtst
          pkgs.libjpeg8
          pkgs.libxkbcommon
          pkgs.libglvnd
          pkgs.curl
        ];

        configurePhase = ''
          export cxxopts_src=${cxxopts_src}
          export nlohmann_json_src=${nlohmann_json_src}
          export sentry_native_src=${sentry_native_src}
        '';

        cmakeFlags = [
          "-Dcxxopts_src=${cxxopts_src}"
          "-Dnlohmann_json_src=${nlohmann_json_src}"
          "-Dsentry_native_src=${sentry_native_src}"
          "-DAURORA_DAWN_PROVIDER=system"
        ];

        buildPhase = ''
          mkdir -p build
          cd build
          cmake ..
          cmake --build .
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin
          install -Dm755 ./dusk $out/bin/dusk

          runHook postInstall
        '';
      };
    in
    {
      packages.x86_64-linux.default = dusk;
    };
}
