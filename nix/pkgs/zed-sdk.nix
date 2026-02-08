# Stereolabs ZED SDK - spatial perception framework for ZED cameras
#
# Packages the official ZED SDK binaries for both x86_64-linux (dev) and
# aarch64-linux (Jetson Orin NX / Aleph). Uses the makeself installer with
# --noexec --target to extract without running the install script.
#
# Usage: LD_LIBRARY_PATH=$out/lib:$LD_LIBRARY_PATH when running ZED apps.
#
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, zstd
, libusb1
, libpng
, gcc
}:

let
  version = "5.1.2";

  # x86_64: Ubuntu 22, CUDA 12.8, TensorRT 10.9
  urlX86 = "https://stereolabs.sfo2.cdn.digitaloceanspaces.com/zedsdk/5.1/ZED_SDK_Ubuntu22_cuda12.8_tensorrt10.9_v${version}.zstd.run";
  sha256X86 = "1v6aikaigrs9h3rwavp98kn3w550clma731lbs0g2df2m6mjjia8";

  # aarch64: Jetson L4T 36.4 (Orin NX)
  urlJetson = "https://stereolabs.sfo2.cdn.digitaloceanspaces.com/zedsdk/5.1/ZED_SDK_Tegra_L4T36.4_v${version}.zstd.run";
  sha256Jetson = "13xiqqkxacw6w4mvh69h20wzfmacwzp5sbnqgcwfzc7q1x695hqm";

  isJetson = stdenv.hostPlatform.system == "aarch64-linux";
  installerUrl = if isJetson then urlJetson else urlX86;
  installerSha256 = if isJetson then sha256Jetson else sha256X86;

  src = fetchurl {
    url = installerUrl;
    sha256 = installerSha256;
  };
in
stdenv.mkDerivation rec {
  pname = "zed-sdk";
  inherit version;

  inherit src;

  nativeBuildInputs = [
    autoPatchelfHook
    zstd
  ];

  buildInputs = [
    libusb1
    libpng
    gcc.cc.lib
  ];

  # CUDA/TensorRT and optional GUI/Jetson libs provided by system or JetPack at runtime
  autoPatchelfIgnoreMissingDeps = [
    "libcuda.so.1"
    "libcudart.so.12"
    "libcublas.so.12"
    "libcufft.so.11"
    "libcurand.so.10"
    "libcusparse.so.12"
    "libcusolver.so.11"
    "libnvrtc.so.12"
    "libcudnn.so.8"
    "libcudnn.so.9"
    "libnvinfer.so.8"
    "libnvinfer.so.10"
    "libnvinfer_plugin.so.8"
    "libnvinfer_plugin.so.10"
    "libnvonnxparser.so.8"
    "libnvonnxparser.so.10"
    "libnvcuvid.so.1"
    "libnvidia-encode.so.1"
    "libarchive.so.13"
    "libjpeg.so.8"
    "libturbojpeg.so.0"
    "libX11.so.6"
    # GUI tools (ZED_Studio, ZED_Media_Server, etc.) - optional at build time
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt5Network.so.5"
    "libQt5OpenGL.so.5"
    "libQt5Svg.so.5"
    "libQt5Sql.so.5"
    "libQt5Xml.so.5"
    "libQt5Concurrent.so.5"
    "libQt5PrintSupport.so.5"
    "libopenblas.so.0"
    "libv4l2.so.0"
    "libEGL.so.1"
    "libOpenGL.so.0"
    "libGLX.so.0"
    # Jetson-specific (L4T)
    "libnvargus_socketclient.so"
    "libnvbufsurftransform.so.1.0.0"
    "libnvbufsurface.so.1.0.0"
  ];

  unpackPhase = ''
    runHook preUnpack
    # Nix store is read-only; copy to build dir and make executable
    cp $src ./installer.run
    chmod +x ./installer.run
    ./installer.run --noexec --target ./extracted
    runHook postUnpack
  '';

  sourceRoot = "extracted";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/include $out/bin $out/share/zed
    mkdir -p $out/etc/udev/rules.d

    cp -r lib/* $out/lib/
    cp -r include/* $out/include/
    cp -r tools/* $out/bin/
    cp 99-slabs.rules $out/etc/udev/rules.d/
    cp get_python_api.py $out/share/zed/ 2>/dev/null || true
    cp zed-config.cmake zed-config-version.cmake $out/share/zed/ 2>/dev/null || true

    # Optional: copy firmware/resources if present (reduces closure; can be omitted for minimal build)
    if [ -d resources ]; then cp -r resources $out/share/zed/; fi
    if [ -d firmware ]; then cp -r firmware $out/share/zed/; fi

    runHook postInstall
  '';

  # Add $out/lib to rpath so binaries find libsl_zed.so (autoPatchelf adds buildInputs only)
  postFixup = ''
    for f in $out/lib/*.so $out/bin/*; do
      if [ -e "$f" ]; then
        patchelf --add-rpath "$out/lib" "$f" 2>/dev/null || true
      fi
    done
  '';

  meta = with lib; {
    description = "Stereolabs ZED SDK - spatial perception for ZED cameras";
    homepage = "https://www.stereolabs.com/developers/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    maintainers = [ ];
  };
}
