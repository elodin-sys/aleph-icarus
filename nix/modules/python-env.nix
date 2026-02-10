# Repo-wide unified Python environment for Aleph Icarus
#
# Single Python environment used by the dev shell, Aleph system, and any
# future services. Includes pyzed (ZED SDK), scientific stack, and optional
# GPU packages. Keep the package list in sync with the dev shell in flake.nix.
#
# Usage:
#   config.aleph-icarus.pythonEnv  — the Python derivation
#   config.aleph-icarus.cudaEnv    — CUDA env vars attrset for services

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.aleph-icarus;
  hasCuda = pkgs ? cudaPackages;
in {
  options.aleph-icarus = {
    enableGpu = mkOption {
      type = types.bool;
      default = true;
      description = "Include GPU-related packages and set CUDA environment variables (for ZED, CuPy, etc.)";
    };

    pythonEnv = mkOption {
      type = types.package;
      readOnly = true;
      description = "The unified Python environment for the repo (dev shell and Aleph)";
    };

    cudaEnv = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      description = "CUDA-related environment variables (empty when GPU is disabled)";
    };
  };

  config = {
    aleph-icarus.pythonEnv = pkgs.python3.withPackages (ps: with ps; [
      numpy
      matplotlib
      (opencv4.override { enableGtk3 = true; })
    ]
    # pyzed and zed-sdk are from our overlay
    ++ [ pkgs.pyzed ]
    ++ (optionals (cfg.enableGpu && hasCuda) [
      # Add CuPy or other GPU packages here if needed
      # cupy
    ]));

    aleph-icarus.cudaEnv = optionalAttrs (cfg.enableGpu && hasCuda) ({
      CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
      LD_LIBRARY_PATH = if config.environment.variables ? LD_LIBRARY_PATH
        then config.environment.variables.LD_LIBRARY_PATH
        else "${pkgs.cudaPackages.cudatoolkit}/lib";
    });

    # Install unified Python env and ZED SDK system-wide
    environment.systemPackages = [
      cfg.pythonEnv
      pkgs.zed-sdk
    ];

    # Append ZED SDK lib path and libjpeg8 compat to LD_LIBRARY_PATH
    # (aleph-dev already sets the base CUDA paths)
    environment.extraInit = let
      # ZED SDK was compiled against Ubuntu's libjpeg8 ABI (libjpeg.so.8).
      # NixOS provides libjpeg-turbo with libjpeg.so.62. Create a compat
      # directory with the needed symlinks.
      zedRuntimeDeps = pkgs.runCommand "zed-runtime-deps" {} ''
        mkdir -p $out/lib
        # Libs the ZED SDK links against that aren't in the default LD_LIBRARY_PATH
        ln -s ${pkgs.xorg.libX11}/lib/libX11.so.6 $out/lib/libX11.so.6
        ln -s ${pkgs.libarchive.lib}/lib/libarchive.so $out/lib/libarchive.so.13
        ln -s ${pkgs.libglvnd}/lib/libEGL.so.1 $out/lib/libEGL.so.1
        ln -s ${pkgs.libglvnd}/lib/libOpenGL.so.0 $out/lib/libOpenGL.so.0
        ln -s ${pkgs.libglvnd}/lib/libGLX.so.0 $out/lib/libGLX.so.0
        # libjpeg8 stub: ZED SDK has a DT_NEEDED for libjpeg.so.8, so the
        # dynamic linker requires it at load time. Create a minimal stub .so
        # with the correct SONAME. The actual JPEG functions will be available
        # from the real libjpeg-turbo via its .so.62 -- the symbol versioning
        # mismatch only matters if the SDK calls version-gated symbols at
        # runtime, which is rare for basic operations.
        ${pkgs.stdenv.cc}/bin/cc -shared -o $out/lib/libjpeg.so.8 \
          -Wl,-soname,libjpeg.so.8 \
          -L${pkgs.libjpeg_turbo.out}/lib -ljpeg
        ln -s ${pkgs.libjpeg_turbo.out}/lib/libturbojpeg.so.0 $out/lib/libturbojpeg.so.0
      '';
    in ''
      export LD_LIBRARY_PATH="${pkgs.zed-sdk}/lib:${zedRuntimeDeps}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    '';

    environment.sessionVariables = optionalAttrs (cfg.enableGpu && hasCuda) {
      CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    };

    # udev rules for ZED camera USB access (vendor 2b03)
    services.udev.packages = [ pkgs.zed-sdk ];
  };
}
