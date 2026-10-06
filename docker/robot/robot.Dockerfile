# Adapted from WATonomous/wato_f1tenth main at 4aa2c4a.
# Changes: generic Jazzy base, Miniconda, ordinary Python workspace, no colcon.
ARG BASE_IMAGE=ros:jazzy-ros-base
FROM ${BASE_IMAGE} AS dependencies
ARG TARGETARCH
ARG MINICONDA_VERSION=py312_26.7.1-1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git less \
        python3-pip python3-venv \
        ros-jazzy-rosbag2 ros-jazzy-rosbag2-storage-default-plugins \
        ros-jazzy-rosbag2-storage-mcap \
    && rm -rf /var/lib/apt/lists/*

# Pin and verify both supported Miniconda installers.
RUN case "${TARGETARCH}" in \
        amd64) arch=x86_64; checksum=b27f60ab63e77eeab50a5417c989120f767e863df32400190d4c7262369f8695 ;; \
        arm64) arch=aarch64; checksum=f6d64a1565e713429683720f59dd6661f5131c2f959a4830438eb1969cde23f7 ;; \
        *) printf 'Unsupported architecture: %s\n' "${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl --fail --location --retry 3 \
        "https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-${arch}.sh" \
        --output /tmp/miniconda.sh \
    && printf '%s  /tmp/miniconda.sh\n' "$checksum" | sha256sum --check - \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh

COPY docker/condarc /opt/conda/.condarc
COPY environment.yml /tmp/environment.yml
RUN /opt/conda/bin/conda env create --file /tmp/environment.yml \
    && /opt/conda/bin/conda clean --all --yes \
    && rm /tmp/environment.yml

FROM dependencies AS build
ARG HOST_UID=1000
ARG HOST_GID=1000

# Match host IDs so edits and outputs in bind mounts belong to the member.
RUN if [ "$HOST_UID" = 0 ]; then \
        echo 'Build as a non-root host user (or set HOST_UID/HOST_GID).' >&2; exit 1; \
    fi \
    && if getent passwd "$HOST_UID" >/dev/null; then \
        userdel "$(getent passwd "$HOST_UID" | cut -d: -f1)"; \
    fi \
    && if ! getent group "$HOST_GID" >/dev/null; then \
        groupadd --gid "$HOST_GID" developer; \
    fi \
    && useradd --uid "$HOST_UID" --gid "$HOST_GID" --create-home --shell /bin/bash developer \
    && mkdir -p /workspace/src/data /workspace/src/annotation-pipeline \
        /workspace/src/segmentation-training /workspace/src/detection-training \
    && chown -R "$HOST_UID:$HOST_GID" /workspace /opt/conda

COPY --chown=${HOST_UID}:${HOST_GID} environment.yml /workspace/environment.yml
COPY --chown=${HOST_UID}:${HOST_GID} src/annotation-pipeline/ /workspace/src/annotation-pipeline/
COPY --chown=${HOST_UID}:${HOST_GID} src/segmentation-training/ /workspace/src/segmentation-training/
COPY --chown=${HOST_UID}:${HOST_GID} src/detection-training/ /workspace/src/detection-training/
COPY docker/wato_ros_entrypoint.sh /usr/local/bin/wato_ros_entrypoint.sh
COPY docker/conda-shell.sh /etc/profile.d/conda-shell.sh
RUN chmod +x /usr/local/bin/wato_ros_entrypoint.sh \
    && printf '\nsource /etc/profile.d/conda-shell.sh\n' >> /home/developer/.bashrc

ENV PATH=/opt/conda/envs/training/bin:/opt/conda/condabin:${PATH}
ENV PYTHONNOUSERSITE=1
USER developer
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/wato_ros_entrypoint.sh"]
CMD ["sleep", "infinity"]
