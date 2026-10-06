#!/usr/bin/env bash
# Adapted from WATonomous/wato_f1tenth main at 4aa2c4a.
# Changes: source Jazzy and activate Conda without launching ROS nodes.
set -e
source /opt/ros/jazzy/setup.bash
source /opt/conda/etc/profile.d/conda.sh
conda activate training
exec "$@"
