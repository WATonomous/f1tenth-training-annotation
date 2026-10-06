# f1tenth-training-annotation

WATonomous F1Tenth/RoboRacer data annotation, detection training, and segmentation
training. Use the familiar `watod` Docker workflow and an ordinary Conda environment.

## Quickstart

Install Docker Engine and Docker Compose 2.30 or newer (for the optional `gpus`
setting). On Windows, run these commands
inside a WSL2 Linux checkout with Docker Desktop's WSL integration enabled.

```bash
./watod build
./watod up -d
./watod -t robot_dev
```

The shell opens in `/workspace` with the `training` Conda environment activated
(Python 3.12 and pip). No ROS nodes are started, and no `colcon build` is needed.

```bash
conda info --envs
python --version
cd /workspace/src/detection-training
# Install the dependencies for your task, then run your Python scripts.
```

From the host:

```bash
./watod ps
./watod exec robot_dev python --version
./watod run --rm robot_dev python --version
./watod down
```

`./watod up` also works in the foreground. Use `up -d` to leave the container running
in the background. The command is spelled **watod**.

## Workspace and persistence

The development container has four separate writable bind mounts:

| Host directory | Container directory | Purpose |
| --- | --- | --- |
| `src/data` | `/workspace/src/data` | Recordings, datasets, exports, runs, checkpoints, caches |
| `src/annotation-pipeline` | `/workspace/src/annotation-pipeline` | Annotation and extraction code |
| `src/segmentation-training` | `/workspace/src/segmentation-training` | Segmentation code |
| `src/detection-training` | `/workspace/src/detection-training` | Detection code |

Edits appear immediately on the host and in the container. Files are written using
your host UID/GID. Data and common model artifacts are ignored by Git and excluded
from image builds. Save outputs under `src/data` so container recreation preserves
them. Python/model caches also live under `src/data/.cache`.

Conda packages installed interactively survive container stop/start, but not
container recreation. Record shared dependencies in `environment.yml` and run
`./watod build` to bake them into the image. The initial environment intentionally
contains only Python and pip so each pipeline can select its own dependencies.
Additional environments can be created with `conda create -n <name> ...`.
Conda uses `conda-forge` with strict channel priority. Docker's local layer cache
reuses the Jazzy/Miniconda dependency stages between builds without registry login.

To put data on another disk, create a host directory and set its absolute path in
`watod-config.local.sh`:

```bash
DATA_DIR="/absolute/path/to/data"
```

## Local configuration

`watod` reads `watod-config.sh`, then applies individual overrides from the
Git-ignored `watod-config.local.sh`. It generates `modules/.env`; do not edit that
file directly. Check the resolved configuration with:

```bash
./watod --verbose config
```

The sole application module is `robot`, preserving the F1Tenth service names:

- `MODE_OF_OPERATION="develop"` (default): `robot_dev`, with all four live mounts.
- `MODE_OF_OPERATION="deploy"`: `robot`, with code copied into the built image and
  only the data directory mounted. Rebuild after code changes in this mode.

Override `PLATFORM="amd64"` or `PLATFORM="arm64"` if needed; by default the host
architecture is detected. Builds install the matching Miniconda installer. A
non-root host UID is required; root users can set `HOST_UID`/`HOST_GID` to the IDs
of the member who owns the mounted directories.

## NVIDIA GPU access (optional)

CPU mode is the default and needs no NVIDIA runtime. On a machine with an NVIDIA
GPU, install the host driver and NVIDIA Container Toolkit, configure Docker, and
add this to `watod-config.local.sh`:

```bash
ENABLE_GPU=true
```

Then recreate the service and inspect the GPU:

```bash
./watod up -d --force-recreate
./watod exec robot_dev nvidia-smi
```

This adds the GPU Compose override; it does not install CUDA-enabled ML libraries.
Install the appropriate framework/CUDA packages into your Conda environment for
your machine. Jetson-specific ML dependencies may need their own configuration.
Set `ENABLE_GPU=false` and recreate the service to return to CPU mode.

## Jazzy bag tools and Conda

The image uses official `ros:jazzy-ros-base` (Ubuntu 24.04) and includes rosbag2's
SQLite and MCAP storage plugins. ROS uses the image's system Python; training uses
Conda Python. The `ros2` executable retains its system-Python shebang:

```bash
ros2 bag info /workspace/src/data/<bag-directory>
/usr/bin/python3 -c 'import rosbag2_py'
```

Use `/usr/bin/python3` for extraction scripts that import apt-installed ROS Python
packages. Do not assume those packages work inside Conda just because both Python
versions are 3.12. In the development shell, Jazzy is sourced and Conda is activated
automatically. For non-interactive `exec` commands needing ROS Python imports, use:

```bash
./watod exec robot_dev bash -lc '/usr/bin/python3 -c "import rosbag2_py"'
```

## Namespaces

Default Compose projects are named:

```text
watod_<repository>_<branch>_<username>
```

For example, Docker Compose generates a development container named
`watod_f1tenth-training-annotation_main_muta-robot_dev-1` on modern Compose.
Networks share that project namespace. No host ports or car devices are requested
in CPU mode, so the F1Tenth stack can run alongside this workspace.

Names are normalized to Docker-compatible characters. Modified or long names gain
a short hash, so branches such as `feature/foo` and `feature-foo` stay distinct.
Detached HEAD uses its commit ID. Override `BRANCH` or `COMPOSE_PROJECT_NAME` locally
when needed. Stop a branch's containers before switching branches, or set `BRANCH`
to the old branch when stopping them afterward.

Local image names use this repository's GHCR namespace:

```text
ghcr.io/watonomous/f1tenth-training-annotation/robot:<branch-tag>
ghcr.io/watonomous/f1tenth-training-annotation/robot:dev_<branch-tag>
```

Building does not publish images. Override `REGISTRY_URL`, `ROBOT_IMAGE`, or `TAG`
locally if needed. Container projects are user-specific; image tags are shared by
branch, so users sharing a Docker daemon can set distinct `TAG` values if their
images contain different dependencies or UID/GID settings.

## Editor and shell completion

Attach VS Code to `robot_dev`, then open `/workspace`. To generate settings for
Conda Python and the recommended Python extensions:

```bash
./watod --setup-dev-env robot_dev
```

Enable completion in the current host Bash shell:

```bash
source watod_scripts/watod-completion.bash
```

`./watod --setup-completion` prints an absolute `source` command you can add to
your host `.bashrc`.

## Infrastructure provenance

The launcher, configuration/helper layout, robot Compose module, and Docker
build-stage conventions are adapted from `WATonomous/wato_f1tenth` **main at
`4aa2c4ab6f52890819f6322561590c1f22f892e0`** (Apache-2.0). Adaptations add isolated
namespaces, Jazzy/Miniconda, four focused source mounts, and optional GPU access.
The original simulation, Foxglove, sample services, car device mounts, and ROS
application packages are outside this repository's narrow training/data scope.
