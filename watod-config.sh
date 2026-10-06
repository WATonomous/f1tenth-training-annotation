# Adapted from WATonomous/wato_f1tenth main at 4aa2c4a.
# Copy individual settings to the Git-ignored watod-config.local.sh to override.

ACTIVE_MODULES="${ACTIVE_MODULES:-robot}"
MODE_OF_OPERATION="${MODE_OF_OPERATION:-develop}" # develop or deploy
REPO_NAME="${REPO_NAME:-f1tenth-training-annotation}"
REGISTRY_URL="${REGISTRY_URL:-ghcr.io/watonomous/f1tenth-training-annotation}"
BASE_IMAGE_OVERRIDE="${BASE_IMAGE_OVERRIDE:-ros:jazzy-ros-base}"
ENABLE_GPU="${ENABLE_GPU:-false}"

# Optional overrides: BRANCH, TAG, COMPOSE_PROJECT_NAME, PLATFORM (amd64/arm64),
# ROBOT_IMAGE, HOST_UID, HOST_GID, and DATA_DIR (absolute host path).
# Default project: watod_<repository>_<branch>_<username>
