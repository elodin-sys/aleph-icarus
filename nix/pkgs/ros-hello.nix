# Example: ROS 2 Humble Hello World Package
#
# This file demonstrates how to create a ROS 2 package using nix-ros-overlay.
# It builds a ROS environment with the demo nodes and creates a wrapper script
# to run the talker demo.
#
# The talker publishes "Hello World" messages to the /chatter topic,
# demonstrating that ROS 2 is working on your Aleph.
#
# Using Humble (LTS) for better compatibility with the Aleph nixpkgs version.
#
# Usage in overlay:
#   ros-hello = final.callPackage ./nix/pkgs/ros-hello.nix {};
#
{ lib
, rosPackages
, writeShellScriptBin
, makeWrapper
, stdenv
}:

let
  # Build a ROS 2 Humble environment with core and demo packages
  rosEnv = rosPackages.humble.buildEnv {
    paths = with rosPackages.humble; [
      ros-core       # Core ROS 2 libraries and tools
      demo-nodes-py  # Python demo nodes (talker/listener)
      demo-nodes-cpp # C++ demo nodes
    ];
  };
in
stdenv.mkDerivation {
  pname = "ros-hello";
  version = "1.0.0";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    
    # Create wrapper script that uses the ROS environment
    makeWrapper ${rosEnv}/bin/ros2 $out/bin/ros-hello \
      --add-flags "run demo_nodes_py talker"
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "ROS 2 Humble Hello World demo for Aleph";
    platforms = platforms.linux;
  };
}

# To test manually on the Aleph:
#   ros-hello              # Run the talker
#   ros2 topic list        # List active topics
#   ros2 topic echo /chatter  # Listen to messages
