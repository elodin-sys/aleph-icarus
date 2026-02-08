# PyZED - Python bindings for the Stereolabs ZED SDK
#
# Built from source (zed-python-api) because the official wheel download
# returns 403 when fetched by Nix. Requires zed-sdk and CUDA at build time.
#
{ lib
, python3
, zed-sdk
, fetchFromGitHub
, patchelf
, libusb1
, cudaPackages ? null
, stdenv
}:

let
  # CUDA toolkit for include/lib at build time (optional on Jetson where SDK may use system CUDA)
  cudaPath = if cudaPackages != null then "${cudaPackages.cudatoolkit}" else "/usr/local/cuda";
  cudaLibDir = if stdenv.hostPlatform.isx86_64 then "lib64" else "lib";
in
python3.pkgs.buildPythonPackage rec {
  pname = "pyzed";
  version = "5.1.2";

  src = fetchFromGitHub {
    owner = "stereolabs";
    repo = "zed-python-api";
    rev = "v${version}";
    sha256 = "1w5h8yx3r02i82ssw07lj90m4z4zpsfxvzc5imdiccxz6kmaa25y";
  };

  sourceRoot = "${src.name}/src";

  nativeBuildInputs = [ python3.pkgs.cython python3.pkgs.numpy patchelf ];

  buildInputs = [
    zed-sdk
    libusb1
    python3.pkgs.numpy
  ] ++ lib.optional (cudaPackages != null) cudaPackages.cudatoolkit;

  propagatedBuildInputs = with python3.pkgs; [
    numpy
    cython
  ];

  # Patch setup.py to:
  # 1. Use our zed-sdk and CUDA paths instead of /usr/local/zed and /usr/local/cuda
  # 2. Remove setup_requires that tries to download packages (no network in Nix sandbox)
  # 3. Remove the SDK version check that expects /usr/local/zed layout
  prePatch = ''
    substituteInPlace setup.py \
      --replace 'zed_path = "/usr/local/zed"' 'zed_path = os.getenv("ZED_SDK_HOME", "/usr/local/zed")' \
      --replace 'cuda_path = "/usr/local/cuda"' 'cuda_path = os.getenv("CUDA_PATH", "/usr/local/cuda")'
    substituteInPlace setup.py \
      --replace 'cuda_path + "/lib64"' 'cuda_path + "/" + os.getenv("CUDA_LIB_DIR", "lib64")'

    # Remove setup_requires to avoid network access during build
    substituteInPlace setup.py \
      --replace "setup_requires=setup_requires," "setup_requires=[],"

    # Disable SDK version check (we provide includes directly)
    substituteInPlace setup.py \
      --replace 'check_zed_sdk_version(zed_path+"/include")' 'print("Skipping ZED SDK version check (Nix build)")'
  '';

  preBuild = ''
    export ZED_SDK_HOME="${zed-sdk}"
    export CUDA_PATH="${cudaPath}"
    export CUDA_LIB_DIR="${cudaLibDir}"
  '';

  # Extension links against libsl_zed at runtime
  postInstall = ''
    for f in $out/lib/python*/site-packages/pyzed/*.so; do
      if [ -e "$f" ]; then
        patchelf --add-rpath "${zed-sdk}/lib" "$f" 2>/dev/null || true
      fi
    done
  '';

  doCheck = false;
  # Import needs ZED SDK libs and GPU at runtime
  pythonImportsCheck = [ ];

  meta = with lib; {
    description = "Python API for the Stereolabs ZED SDK";
    homepage = "https://github.com/stereolabs/zed-python-api";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    maintainers = [ ];
  };
}
