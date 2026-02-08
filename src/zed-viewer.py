#!/usr/bin/env python3
"""Live video stream from a ZED camera using OpenCV.

Run from the nix develop shell:
    python3 src/zed-viewer.py

Press 'q' to quit.
"""

import os
import pyzed.sl as sl
import cv2


def main():
    cam = sl.Camera()

    init = sl.InitParameters()
    init.camera_resolution = sl.RESOLUTION.HD720
    init.camera_fps = 30
    init.optional_settings_path = os.environ.get(
        "ZED_SETTINGS_PATH", "/usr/local/zed/settings"
    )

    status = cam.open(init)
    if status != sl.ERROR_CODE.SUCCESS:
        print(f"Failed to open camera: {status}")
        return

    info = cam.get_camera_information()
    print(f"Camera: {info.camera_model}, S/N: {info.serial_number}")
    print("Press 'q' to quit")

    image = sl.Mat()
    runtime = sl.RuntimeParameters()

    while True:
        if cam.grab(runtime) == sl.ERROR_CODE.SUCCESS:
            cam.retrieve_image(image, sl.VIEW.LEFT)
            frame = image.get_data()
            cv2.imshow("ZED Live", frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    cam.close()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
