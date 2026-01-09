# ROS 2 Humble Hello World NixOS Module
#
# This module demonstrates how to run ROS 2 nodes as systemd services on Aleph.
# The ros-hello service runs a talker node that publishes "Hello World" messages
# to the /chatter topic, proving ROS 2 is working correctly.
#
# Usage in your NixOS configuration:
#   services.ros-hello = {
#     enable = true;
#   };
#
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ros-hello;
in
{
  #############################################################################
  # Module Options
  #############################################################################
  options.services.ros-hello = {
    enable = mkEnableOption "ROS 2 Humble hello world demo service";

    user = mkOption {
      type = types.str;
      default = "ros-hello";
      description = "User account under which the ROS service runs.";
    };

    group = mkOption {
      type = types.str;
      default = "ros-hello";
      description = "Group under which the ROS service runs.";
    };
  };

  #############################################################################
  # Module Implementation
  #############################################################################
  config = mkIf cfg.enable {
    # Create the service user and group
    users.users.${cfg.user} = mkIf (cfg.user == "ros-hello") {
      isSystemUser = true;
      group = cfg.group;
      description = "ROS 2 Hello service daemon user";
    };

    users.groups.${cfg.group} = mkIf (cfg.group == "ros-hello") {};

    # Define the systemd service
    systemd.services.ros-hello = {
      description = "ROS 2 Humble Hello World Talker";
      
      # Start after network is available
      after = [ "network.target" ];
      
      # Enable the service to start on boot
      wantedBy = [ "multi-user.target" ];

      # ROS needs a writable home directory for logs
      environment = {
        HOME = "/var/lib/ros-hello";
        ROS_HOME = "/var/lib/ros-hello/.ros";
        ROS_LOG_DIR = "/var/lib/ros-hello/.ros/log";
      };

      serviceConfig = {
        # The executable to run
        ExecStart = "${pkgs.ros-hello}/bin/ros-hello";
        
        # Run as the configured user
        User = cfg.user;
        Group = cfg.group;
        
        # Create state directory for ROS logs
        StateDirectory = "ros-hello";
        StateDirectoryMode = "0755";
        
        # Restart policy - keep trying if it fails
        Restart = "always";
        RestartSec = "5s";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        
        # Logging - stdout/stderr go to journald automatically
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };
}

# Testing the ROS 2 demo on Aleph:
#
# 1. Check if the service is running:
#    systemctl status ros-hello
#
# 2. View the talker output:
#    journalctl -u ros-hello -f
#
# 3. List ROS topics (if ros-core is in systemPackages):
#    ros2 topic list
#
# 4. Echo the /chatter topic:
#    ros2 topic echo /chatter
