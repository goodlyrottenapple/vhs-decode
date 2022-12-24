{
  description = "Python application flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    mach-nix.url = "github:davhau/mach-nix";
  };

  outputs = { self, nixpkgs, mach-nix, flake-utils, ... }:
    let
      pythonVersion = "python39";
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        mach = mach-nix.lib.${system};

        samplerate = with mach; buildPythonPackage {
          src = fetchPypiSdist "samplerate" "0.1.0";
          pname = "samplerate";
          version = "0.1.0";
          requirements = ''
            cffi>=1.0.0
            numpy==1.22.4
            enum34; python_version < "3.4"
            mock; python_version < "3.3"
            pytest-runner
          '';
          postPatch = ''
            substituteInPlace samplerate/lowlevel.py \
              --replace "_find_library('samplerate')" '"${pkgs.libsamplerate.out}/lib/libsamplerate.${if pkgs.stdenv.isDarwin then "dylib" else "so"}"'
          '';
        };

        ld-decode = with pkgs; stdenv.mkDerivation rec {
          pname = "ld-decode";
          version = "0.1.0";
          
          src = ./.;

          nativeBuildInputs = [ cmake pkg-config ];
          buildInputs = [ 
            qt6.qtbase
            qt6.wrapQtAppsHook
            fftw
            ffmpeg-full
          ];

          cmakeFlags = [ 
            "-DBUILD_PYTHON=OFF"
            "-DUSE_QWT=OFF"
          ];
        };



        vhs-decode = with mach; buildPythonPackage {
            pname = "vhs-decode";
            version = "1.0";
            requirements = builtins.readFile ./requirements.txt;
            requirementsExtra = "Cython";
            propagatedBuildInputs = [ samplerate pkgs.ffmpeg-full ld-decode ];
            src = ./.;

            postPatch = ''
              patchShebangs *.sh
            '';

            postInstall = ''
              for prog in $out/bin/gen_*
              do
                wrapProgram $prog \
                  --set PATH ${with pkgs; lib.makeBinPath [
                    ld-decode
                    ffmpeg-full
                  ]}
              done
            '';
          };
      in
      rec
      {
        packages = {
          inherit vhs-decode ld-decode;
          default = packages.vhs-decode;
        };
      }
    );
}