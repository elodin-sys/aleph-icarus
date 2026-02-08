#!/usr/bin/env python3
"""Quick smoke test for ZED camera (no display required).

Run from the nix develop shell:
    python3 src/zed-test.py
"""

import os
import pyzed.sl as sl


def main():
    cam = sl.Camera()

    init = sl.InitParameters()
    init.depth_mode = sl.DEPTH_MODE.NONE
    init.optional_settings_path = os.environ.get(
        "ZED_SETTINGS_PATH", "/usr/local/zed/settings"
    )

    status = cam.open(init)
    if status == sl.ERROR_CODE.SUCCESS:
        info = cam.get_camera_information()
        print(f"Camera: {info.camera_model}, S/N: {info.serial_number}")
        print(f"FW: {info.camera_configuration.firmware_version}")
        cam.close()
        print("Camera test passed!")
    else:
        print(f"Open failed: {status}")


if __name__ == "__main__":
    main()
