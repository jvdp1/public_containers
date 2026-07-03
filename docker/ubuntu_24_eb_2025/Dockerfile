FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies (Lmod build deps included; no apt lmod package)
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    lua5.3 \
    liblua5.3-dev \
    lua-posix \
    lua-posix-dev \
    tcl \
    tcl-dev \
    wget \
    pkg-config \
    bzip2 \
    gzip \
    tar \
    unzip \
    patch \
    make \
    gnuplot \
    openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Lmod from source using configure as recommended by the Lmod docs
# https://lmod.readthedocs.io/en/latest/030_installing.html
RUN wget -q https://github.com/TACC/Lmod/archive/refs/tags/8.7.tar.gz -O /tmp/lmod.tar.gz && \
    tar xf /tmp/lmod.tar.gz -C /tmp && \
    cd /tmp/Lmod-8.7 && \
    ./configure --prefix=/opt/apps && \
    make install && \
    rm -rf /tmp/lmod.tar.gz /tmp/Lmod-8.7

# Integrate Lmod into shells via /etc/profile.d (recommended method)
RUN ln -s /opt/apps/lmod/lmod/init/profile   /etc/profile.d/z00_lmod.sh && \
    ln -s /opt/apps/lmod/lmod/init/cshrc     /etc/profile.d/z00_lmod.csh

# For Ubuntu: ensure non-login interactive bash shells also source /etc/profile.d/*.sh
RUN printf '\nif ! shopt -q login_shell; then\n  if [ -d /etc/profile.d ]; then\n    for i in /etc/profile.d/*.sh; do\n      if [ -r "$i" ]; then . "$i"; fi\n    done\n  fi\nfi\n' >> /etc/bash.bashrc

# Install EasyBuild via pip into a virtual environment
RUN python3 -m venv /opt/easybuild-venv && \
    /opt/easybuild-venv/bin/pip install --upgrade pip && \
    /opt/easybuild-venv/bin/pip install easybuild "cmake==3.30.0" fypp fprettify ford

# Add EasyBuild venv to PATH
ENV PATH="/opt/easybuild-venv/bin:$PATH"

# Set EasyBuild prefix
ENV EASYBUILD_PREFIX=/opt/easybuild
ENV MODULEPATH=/opt/easybuild/modules/all

# Make Lmod available to non-login shells (e.g. Docker RUN instructions)
ENV LMOD_CMD=/opt/apps/lmod/lmod/libexec/lmod
ENV LMOD_DIR=/opt/apps/lmod/lmod/libexec
ENV BASH_ENV=/opt/apps/lmod/lmod/init/bash

# Create EasyBuild directories and a non-root user to run EasyBuild
RUN mkdir -p /opt/easybuild && \
    useradd -m -s /bin/bash easybuild && \
    chown -R easybuild:easybuild /opt/easybuild

# Switch to non-root user for EasyBuild
USER easybuild

# Install intel-compilers + MKL (iimkl/2025b) via EasyBuild
# eb is available via PATH from the venv ENV set above
RUN eb iimkl-2025b.eb --robot --accept-eula-for=Intel-oneAPI 2>&1 | tee /tmp/eb-iimkl.log

# Install CUDA 12.6.0 (matching the 2023a toolchain) via EasyBuild
RUN eb CUDA-12.6.0.eb --robot --accept-eula-for=CUDA 2>&1 | tee /tmp/eb-cuda.log

# Switch back to root
USER root

# Set working directory
WORKDIR /root

CMD ["/bin/bash", "--login"]
