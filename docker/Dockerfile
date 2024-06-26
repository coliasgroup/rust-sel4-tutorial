#
# Copyright 2024, Colias Group, LLC
#
# SPDX-License-Identifier: BSD-2-Clause
#

FROM debian:bookworm

RUN apt-get update -q && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    # for qemu
    pkg-config \
    libglib2.0-dev \
    libaio-dev \
    libpixman-1-dev \
    libslirp-dev \
    # for seL4
    python3-dev \
    python3-venv \
    cmake \
    ninja-build \
    device-tree-compiler \
    libxml2-utils \
    # for microkit
    pandoc \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-fonts-recommended \
    # for bindgen
    libclang-dev \
    # for test scripts
    python3-pexpect \
    python3-requests \
    # for book
    linkchecker \
    # for hacking
    bash-completion \
    man \
    sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN curl -sSf https://sh.rustup.rs | \
        bash -s -- -y --no-modify-path \
            --default-toolchain nightly-2024-05-01 \
            --component rust-src

ENV PATH=/root/.cargo/bin:$PATH

RUN cargo install mdbook@0.4.36

RUN set -eux; \
    host=$(uname -m); \
    url="https://developer.arm.com/-/media/Files/downloads/gnu/12.2.rel1/binrel/arm-gnu-toolchain-12.2.rel1-$host-aarch64-none-elf.tar.xz"; \
    dst=/opt/gcc-aarch64-none-elf; \
    mkdir -p $dst; \
    curl -sSfL "$url" | tar -xJ -C $dst --strip-components=1;

ENV PATH=/opt/gcc-aarch64-none-elf/bin:$PATH

RUN set -eux; \
    version=7.2.0; \
    url="https://download.qemu.org/qemu-${version}.tar.xz"; \
    curl -sSfL "$url" | tar -xJ; \
    cd qemu-*; \
    qemu_arm_virt_sp804_url="https://github.com/coliasgroup/qemu/commit/cd3b78de4b5a8d7c79ae99dab2b5e0ab1ba0ffac.patch"; \
    curl -sSfL "$qemu_arm_virt_sp804_url" | patch -p1; \
    ./configure \
        --prefix=/opt/qemu \
        --enable-linux-aio \
        --enable-slirp \
        --target-list=aarch64-softmmu; \
    make -j$(nproc) all; \
    make install; \
    rm -rf $(pwd);

ENV PATH=/opt/qemu/bin:$PATH

ENV SEL4_INSTALL_DIR=/opt/seL4

RUN set -eux; \
    git clone \
        https://github.com/seL4/seL4.git \
        --config advice.detachedHead=false; \
    cd seL4; \
    git checkout 0260fba168b74dd2504c9447f2fa8da1161ead87;

RUN set -eux; \
    cd seL4; \
    python3 -m venv pyenv; \
    export PATH=$(realpath ./pyenv/bin):$PATH; \
    pip install tools/python-deps; \
    cmake \
        -DCROSS_COMPILER_PREFIX=aarch64-none-elf- \
        -DCMAKE_INSTALL_PREFIX=$SEL4_INSTALL_DIR \
        -DKernelPlatform=qemu-arm-virt \
        # TODO further develop kernel loader to make KernelArmHypervisorSupport=ON unecessary
        -DKernelArmHypervisorSupport=ON \
        -DKernelVerificationBuild=OFF \
        -DARM_CPU=cortex-a57 \
        -G Ninja \
        -S . \
        -B build; \
    ninja -C build all; \
    ninja -C build install; \
    rm -rf $(pwd);

RUN set -eux; \
    url="https://github.com/seL4/rust-sel4"; \
    rev="a20aab14c0533d3145a2db75020e60151ce9b78f"; \
    common_args="--git $url --rev $rev --root $SEL4_INSTALL_DIR"; \
    CC_aarch64_unknown_none=aarch64-none-elf-gcc \
    SEL4_PREFIX=$SEL4_INSTALL_DIR \
        cargo install \
            -Z build-std=core,compiler_builtins \
            -Z build-std-features=compiler-builtins-mem \
            --target aarch64-unknown-none \
            $common_args \
            sel4-kernel-loader; \
    cargo install \
        $common_args \
        sel4-kernel-loader-add-payload;

ENV MICROKIT_SDK_VERSION=1.2.6
ENV MICROKIT_SDK=/opt/microkit/microkit-sdk-$MICROKIT_SDK_VERSION

RUN set -eux; \
    git clone \
        https://github.com/seL4/microkit.git \
        --config advice.detachedHead=false; \
    cd microkit; \
    git checkout f0939852c62c629346cd3eddbe7d8922eca8530a; \
    git clone \
        https://github.com/seL4/seL4.git \
        --config advice.detachedHead=false; \
    cd seL4; \
    git checkout 57975d485397ce1744f7163644dd530560d0b7ec;

RUN set -eux; \
    cd microkit; \
    python3 -m venv pyenv; \
    export PATH=$(realpath ./pyenv/bin):$PATH; \
    pip install seL4/tools/python-deps; \
    pip install -r requirements.txt; \
    python3 build_sdk.py --sel4 ./seL4 --tool-target-triple $(uname -m)-unknown-linux-gnu; \
    mkdir $(dirname $MICROKIT_SDK); \
    mv release/microkit-sdk-$MICROKIT_SDK_VERSION $MICROKIT_SDK; \
    rm -rf $HOME/.cache/pyoxidizer; \
    rm -rf $(pwd);

ARG UID
ARG GID

RUN set -eux; \
    if [ $UID -eq 0 ]; then \
        if [ $GID -ne 0 ]; then \
            echo "error: \$UID == 0 but \$GID != 0" >&2; \
            exit 1; \
        fi; \
    else \
        if getent passwd $UID; then \
            echo "error: \$UID $UID already exists" >&2; \
            exit 1; \
        fi; \
        if ! getent group $GID; then \
            groupadd --gid $GID x; \
        fi; \
        useradd --uid $UID --gid $GID --groups sudo --create-home x; \
    fi;

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER $UID

RUN set -eux; \
    if [ $UID -ne 0 ]; then \
        curl -sSf https://sh.rustup.rs | \
            bash -s -- -y --no-modify-path --default-toolchain none; \
    fi;

ENV PATH=/home/x/.cargo/bin:$PATH

WORKDIR /work
