# Aleph Template Project
#
# This flake demonstrates the recommended patterns for developing and deploying
# software to the Aleph flight computer using Nix and NixOS.
#
# Four example patterns are included:
#   1. Using packages from nixpkgs (example-nixpkgs)
#   2. Building packages from source (example-from-source)
#   3. Local Python application as systemd service (hello-service)
#   4. ROS 2 Humble package using nix-ros-overlay (ros-hello)
#
# Build command:
#   nix build --accept-flake-config .#packages.aarch64-linux.toplevel --show-trace
#
# Deploy command:
#   ./deploy.sh
#
{
  nixConfig = {
    extra-substituters = [
      "https://elodin-nix-cache.s3.us-west-2.amazonaws.com"
      "https://cache.nixos.org"
      "https://ros.cachix.org"
    ];
    extra-trusted-public-keys = [
      "elodin-cache-1:vvbmIQvTOjcBjIs8Ri7xlT2I3XAmeJyF5mNlWB+fIwM="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
    ];
  };

  inputs = {
    aleph.url = "github:elodin-sys/elodin?ref=main&dir=aleph";
    flake-utils.follows = "aleph/flake-utils";
    nixpkgs.follows = "aleph/nixpkgs";
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
    self.submodules = true;
  };

  outputs = {
    nixpkgs,
    aleph,
    nix-ros-overlay,
    flake-utils,
    self,
    ...
  }: rec {
    system = "aarch64-linux";

    ###########################################################################
    # Custom Overlay
    #
    # This overlay makes your custom packages available to the NixOS system.
    # Packages defined here can be used in environment.systemPackages or
    # referenced by modules.
    ###########################################################################
    overlays.default = final: prev: {
      # Pattern 1: Clean nixpkgs dependency
      # Wraps btop with a custom launcher script
      example-nixpkgs = final.callPackage ./nix/pkgs/example-nixpkgs.nix {};

      # Pattern 2: Build from source
      # Fetches and builds lazygit from GitHub
      example-from-source = final.callPackage ./nix/pkgs/example-from-source.nix {};

      # Pattern 3: Local Python application
      # Packages the hello-service from src/hello-service/
      hello-service = final.callPackage ./nix/pkgs/hello-service.nix {
        src = ./src/hello-service;
      };

      # Pattern 4: ROS 2 package using nix-ros-overlay
      # Creates a ROS 2 Jazzy environment with demo nodes
      ros-hello = final.callPackage ./nix/pkgs/ros-hello.nix {};

      # ZED SDK (Stereolabs) and Python bindings
      zed-sdk = final.callPackage ./nix/pkgs/zed-sdk.nix {};
      pyzed = final.callPackage ./nix/pkgs/pyzed.nix {
        zed-sdk = final.zed-sdk;
        cudaPackages = final.cudaPackages or null;
      };
    };

    ###########################################################################
    # NixOS Module
    #
    # This module configures your Aleph system. It imports:
    #   - Aleph hardware and base modules (required)
    #   - Your custom modules (for services you create)
    ###########################################################################
    nixosModules.default = {config, pkgs, ...}: {
      imports = with aleph.nixosModules; [
        #######################################################################
        # Aleph Hardware Modules (required)
        #######################################################################
        jetpack   # Core module required for NVIDIA Jetpack/Orin support
        hardware  # Aleph-specific hardware, kernel, and device tree
        fs        # SD card image building support

        #######################################################################
        # Aleph Networking Modules (optional - enable as needed)
        #######################################################################
        # usb-eth     # USB ethernet gadget for direct connection
        wifi          # WiFi support using iwd

        #######################################################################
        # Aleph Tooling Modules (recommended)
        #######################################################################
        aleph-setup   # First-boot setup wizard for WiFi and user config
        aleph-base    # Sensible default configuration for development
        aleph-dev     # Development packages (CUDA, OpenCV, git, etc.)

        #######################################################################
        # Your Custom Modules
        #######################################################################
        ./nix/modules/hello-service.nix
        ./nix/modules/ros-hello.nix
        ./nix/modules/python-env.nix
      ];

      # Apply overlays (order matters!)
      # 1. jetpack: NVIDIA Jetpack packages
      # 2. aleph: Aleph-specific packages and device tree
      # 3. nix-ros-overlay: ROS 2 packages
      # 4. default: Your custom packages
      nixpkgs.overlays = [
        aleph.overlays.jetpack
        aleph.overlays.default
        nix-ros-overlay.overlays.default
        overlays.default
      ];

      nixpkgs.config.allowUnfree = true;

      system.stateVersion = "25.05";
      i18n.supportedLocales = [(config.i18n.defaultLocale + "/UTF-8")];

      #########################################################################
      # Enable the Hello Service (Pattern 3 demonstration)
      #########################################################################
      services.hello-service = {
        enable = true;
        message = "Hello from Aleph Template Project!";
        interval = 30;  # Log every 30 seconds
      };

      #########################################################################
      # Enable the ROS 2 Hello Service (Pattern 4 demonstration)
      #########################################################################
      services.ros-hello = {
        enable = true;
      };

      #########################################################################
      # System Packages
      #
      # Include packages you want available system-wide.
      # Your overlay packages are available via `pkgs.<name>`.
      #########################################################################
      environment.systemPackages = with pkgs; [
        # Pattern 1: nixpkgs wrapper package
        example-nixpkgs   # Available as 'aleph-monitor' command

        # Pattern 2: Built from source
        example-from-source  # Available as 'lazygit' command

        # The hello-service package is managed by its systemd service,
        # but you can also add it here if you want CLI access:
        # hello-service

        # Common development tools
        git
        vim
        tmux
        htop
        btop

        # Network utilities
        wget
        curl

        # Hardware debugging
        usbutils
        pciutils
        lshw

        # Python for scripting
        python3

        # ROS 2 Humble CLI tools for manual testing
        # Use: ros2 topic list, ros2 topic echo /chatter
        (rosPackages.humble.buildEnv {
          paths = with rosPackages.humble; [
            ros-core
            demo-nodes-py
          ];
        })
      ];

      #########################################################################
      # User Configuration
      #
      # Configure your Aleph user account here.
      #########################################################################
      users.users.aleph = {
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          # Your SSH public key (from ssh/aleph-key.pub)
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKtPjReJktl58C9GKjgl0pkUZ87XqpYKfOiSqXrhwoXq aleph-key"
        ];
        extraGroups = [
          "wheel"         # sudo access
          "dialout"       # Serial port access
          "video"         # Video device access
          "audio"         # Audio device access
          "networkmanager"
          "podman"        # Container support
        ];
        shell = "/run/current-system/sw/bin/bash";
      };

      #########################################################################
      # SSH Configuration
      #########################################################################
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = true;
          PubkeyAuthentication = true;
          PermitRootLogin = "yes";
        };
      };

      #########################################################################
      # Security & Nix Settings
      #########################################################################
      security.sudo.wheelNeedsPassword = false;
      nix.settings.trusted-users = ["@wheel" "root" "ubuntu" "aleph"];
      networking.firewall.enable = false;
    };

    ###########################################################################
    # NixOS Configurations
    #
    # Define different system configurations here. The 'default' configuration
    # is used by deploy.sh. You can add more for different setups.
    ###########################################################################
    nixosConfigurations = {
      default = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [nixosModules.default];
      };

      # Example: Add additional configurations for different use cases
      # minimal = nixpkgs.lib.nixosSystem {
      #   inherit system;
      #   modules = [nixosModules.minimal];
      # };
    };

    ###########################################################################
    # Dev Shells (x86_64-linux for local development with ZED camera)
    ###########################################################################
    devShells."x86_64-linux" = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
          cudaSupport = true;
        };
        overlays = [
          # Replace TensorRT's requireFile (needs NVIDIA login) with a fetchurl
          (final: prev: {
            cudaPackages = prev.cudaPackages.overrideScope (cfinal: cprev: {
              tensorrt = cprev.tensorrt.overrideAttrs (old: {
                src = final.fetchurl {
                  url = "https://elo-public-misc.s3.us-east-2.amazonaws.com/TensorRT-10.9.0.34.Linux.x86_64-gnu.cuda-12.8.tar.gz";
                  hash = "sha256-M74OYeO/F3u7yrtIkr8BPwyKxx0r5z8oA4SKOCyxQnI=";
                };
              });
            });
          })
        ];
      };
      zed-sdk = pkgs.callPackage ./nix/pkgs/zed-sdk.nix {};
      pyzed = pkgs.callPackage ./nix/pkgs/pyzed.nix {
        inherit zed-sdk;
        cudaPackages = pkgs.cudaPackages or null;
      };
      opencv4-gtk = pkgs.python3Packages.opencv4.override { enableGtk3 = true; };
      pythonEnv = pkgs.python3.withPackages (ps: with ps; [
        pyzed
        numpy
        matplotlib
        opencv4-gtk
      ]);
    in {
      default = pkgs.mkShell {
        name = "aleph-icarus-dev";
        buildInputs = [
          zed-sdk
          pythonEnv
          pkgs.usbutils
          # Runtime libs needed by ZED SDK shared objects
          pkgs.libjpeg_turbo
          pkgs.xorg.libX11
          pkgs.libarchive
          # CUDA + TensorRT for depth/AI features
          pkgs.cudaPackages.cuda_cudart
          pkgs.cudaPackages.tensorrt
        ];
        env = {
          PYTHONHOME = "${pythonEnv}";
        };
        shellHook = ''
          # --- LD_LIBRARY_PATH: ZED SDK + CUDA/TensorRT + runtime deps ---
          export LD_LIBRARY_PATH="${zed-sdk}/lib:${pkgs.cudaPackages.cuda_cudart.lib}/lib:${pkgs.cudaPackages.tensorrt.lib}/lib:${pkgs.libjpeg_turbo.out}/lib:${pkgs.xorg.libX11}/lib:${pkgs.libarchive.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

          # Symlink host NVIDIA driver and libjpeg8 into a temp dir (these must
          # come from the host system, not nixpkgs)
          __compat_dir="$(mktemp -d)"
          for lib in /usr/lib/x86_64-linux-gnu/libcuda.so* \
                     /usr/lib/x86_64-linux-gnu/libnvcuvid.so* \
                     /usr/lib/x86_64-linux-gnu/libnvidia-encode.so* \
                     /usr/lib/x86_64-linux-gnu/libnvidia-ml.so* \
                     /usr/lib/x86_64-linux-gnu/libjpeg.so.8* \
                     /usr/lib/x86_64-linux-gnu/libturbojpeg.so*; do
            [ -e "$lib" ] && ln -sf "$lib" "$__compat_dir/" 2>/dev/null
          done
          export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$__compat_dir"

          # --- One-time host setup (requires sudo) ---
          __zed_needs_setup=false
          [ ! -f /etc/udev/rules.d/99-slabs.rules ] && __zed_needs_setup=true
          [ ! -d /usr/local/zed/settings ] && __zed_needs_setup=true
          [ ! -L /usr/local/zed/lib ] && __zed_needs_setup=true
          # resources must be a real writable dir (not a symlink to read-only nix store)
          [ -L /usr/local/zed/resources ] && __zed_needs_setup=true
          [ ! -w /usr/local/zed/resources ] && __zed_needs_setup=true

          if [ "$__zed_needs_setup" = true ]; then
            echo ""
            echo "First-time ZED setup (requires sudo)..."
            sudo rm -rf /usr/local/zed/lib /usr/local/zed/resources 2>/dev/null
            sudo mkdir -p /usr/local/zed/settings /usr/local/zed/resources \
              && sudo chmod 777 /usr/local/zed/settings /usr/local/zed/resources \
              && sudo ln -sfn "${zed-sdk}/lib" /usr/local/zed/lib \
              && sudo cp -n "${zed-sdk}"/share/zed/resources/* /usr/local/zed/resources/ 2>/dev/null \
              && sudo cp "${zed-sdk}/etc/udev/rules.d/99-slabs.rules" /etc/udev/rules.d/ \
              && sudo udevadm control --reload-rules \
              && sudo udevadm trigger \
              && echo "ZED setup complete." \
              || echo "Warning: setup failed. Camera access may require manual configuration."
          fi

          # ZED SDK stores calibration files here (created above)
          export ZED_SETTINGS_PATH="/usr/local/zed/settings"

          # --- Auto-download calibration files for connected ZED cameras ---
          # The SDK's built-in downloader fails in Nix (missing CA certs for its
          # bundled libcurl), so we fetch them ourselves via sysfs.
          for __dev in /sys/bus/usb/devices/*/; do
            [ "$(cat "$__dev/idVendor" 2>/dev/null)" = "2b03" ] || continue
            sn="$(cat "$__dev/serial" 2>/dev/null)"
            echo "$sn" | grep -qE '^[0-9]+$' || continue
            __calib="$ZED_SETTINGS_PATH/SN''${sn}.conf"
            if [ ! -f "$__calib" ]; then
              echo "Downloading calibration for ZED S/N $sn..."
              ${pkgs.curl}/bin/curl -sL "https://www.stereolabs.com/developers/calib/?SN=$sn" -o "$__calib" 2>/dev/null \
                && echo "  Saved to $__calib" \
                || echo "  Warning: failed to download calibration (check network)"
            fi
          done

          echo ""
          echo "aleph-icarus development shell (ZED SDK ${zed-sdk.version} + Python)"
          echo "  Python: $(which python3)"
          echo ""
          echo "Try: python3 src/zed-viewer.py"
        '';
      };
    };

    ###########################################################################
    # Package Outputs
    #
    # These are the build targets available via `nix build`.
    ###########################################################################
    packages.aarch64-linux = {
      # SD card image for initial Aleph setup
      sdimage = aleph.packages.aarch64-linux.sdimage;

      # System toplevel - used by deploy.sh for OTA updates
      default = nixosConfigurations.default.config.system.build.toplevel;
      toplevel = nixosConfigurations.default.config.system.build.toplevel;
    };
  };
}
