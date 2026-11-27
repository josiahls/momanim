FROM ubuntu:24.04

ENV CONTAINER_USER=mojo_user
ENV CONTAINER_GROUP=mojo_group
ENV CONTAINER_UID=1000

LABEL maintainer=dl.mlsedevops@amd.com

ARG DEBIAN_FRONTEND=noninteractive
ARG ROCM_VERSION=6.4.1
ARG AMDGPU_VERSION=6.4.1

# Prefer AMDGPU/ROCm packages over Ubuntu's older rocm-* packages in Noble (5.7.x).
RUN printf '%s\n' \
    'Package: *' \
    'Pin: release o=repo.radeon.com' \
    'Pin-Priority: 600' \
    > /etc/apt/preferences.d/rocm-pin-600

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg libnuma-dev \
    && curl -fsSL https://repo.radeon.com/rocm/rocm.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/rocm-archive-keyring.gpg \
    && printf '%s\n' \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/rocm-archive-keyring.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION}/ noble main" \
        > /etc/apt/sources.list.d/rocm.list \
    && printf '%s\n' \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/rocm-archive-keyring.gpg] https://repo.radeon.com/amdgpu/${AMDGPU_VERSION}/ubuntu noble main" \
        > /etc/apt/sources.list.d/amdgpu.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        sudo \
        build-essential \
        rocm-dev \
        git \
        cmake \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="${PATH}:/opt/rocm/bin"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        rsync \
        curl \
        gcc \
        g++ \
        apt-transport-https \
        python3.11-dev \
        python3.11-venv \
        gdb \
        libglib2.0-dev \
        libxext6 \
        libsm6 \
        nano \
        tree \
        wget \
        llvm \
        clang \
        zlib1g-dev \
        gnupg \
        nasm \
        xauth \
        valgrind \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN if id ubuntu &>/dev/null; then userdel -r ubuntu; fi \
    && existing_gid="$(getent group "${CONTAINER_UID}" | cut -d: -f1 || true)" \
    && if [ -n "${existing_gid}" ] && [ "${existing_gid}" != "${CONTAINER_GROUP}" ]; then groupdel "${existing_gid}"; fi \
    && addgroup --gid "${CONTAINER_UID}" "${CONTAINER_GROUP}" \
    && adduser --uid "${CONTAINER_UID}" --gid "${CONTAINER_UID}" \
        --home "/home/${CONTAINER_USER}" \
        --shell /bin/bash \
        --disabled-password \
        --gecos "" \
        "${CONTAINER_USER}" \
    && usermod -aG sudo,video "${CONTAINER_USER}" \
    && printf '%s\n' "${CONTAINER_USER} ALL=(ALL) NOPASSWD:ALL" \
        > "/etc/sudoers.d/${CONTAINER_USER}" \
    && chmod 0440 "/etc/sudoers.d/${CONTAINER_USER}"

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 \
    && ln -fs /usr/bin/python3.11 /usr/bin/python3

WORKDIR /home/${CONTAINER_USER}
RUN mkdir -p "/home/${CONTAINER_USER}/.local/lib" "/home/${CONTAINER_USER}/.local/bin" \
    && chown -R "${CONTAINER_USER}:${CONTAINER_GROUP}" "/home/${CONTAINER_USER}"

USER ${CONTAINER_USER}
ENV PATH="/home/${CONTAINER_USER}/.local/bin:/opt/rocm/bin:${PATH}"

SHELL ["/bin/bash", "-c"]
ENV SHELL=/bin/bash

RUN curl -fsSL https://pixi.sh/install.sh | sh
ENV PATH="/home/${CONTAINER_USER}/.pixi/bin:/home/${CONTAINER_USER}/.modular/bin:${PATH}"

RUN echo 'eval "$(pixi completion --shell bash)"' >> "/home/${CONTAINER_USER}/.bashrc"

WORKDIR /home/${CONTAINER_USER}