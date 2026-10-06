#!/usr/bin/env bash
# Adapted from WATonomous/wato_f1tenth main at 4aa2c4a.
# Changes: configure container Python directly instead of copying ROS to /tmp.
case "$SERVICE_NAME" in
    robot|robot_dev) ;;
    *) printf 'Choose robot_dev (develop) or robot (deploy).\n' >&2; exit 1 ;;
esac
mkdir -p "$MONO_DIR/.vscode"
cp "$MONO_DIR/config/sample_settings/settings.json" "$MONO_DIR/.vscode/settings.json"
cp "$MONO_DIR/config/sample_settings/extensions.json" "$MONO_DIR/.vscode/extensions.json"
printf 'VS Code configured. Attach to %s, then open /workspace.\n' "$SERVICE_NAME"
