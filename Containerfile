# Cross-compilation environment for monome norns (Raspberry Pi, Raspbian Buster armhf).
#
# Debian Buster is used on purpose: its glibc (2.28) and libstdc++ (GCC 8) match
# the norns image, so the resulting .so files load on the device. Building with a
# newer distro links against newer symbol versions (e.g. GLIBC_2.29 exp/log/pow)
# and the plugins then fail to load in scsynth on norns.
FROM docker.io/library/debian:buster

# Buster is EOL; packages live on archive.debian.org now.
RUN printf '%s\n' \
      'deb http://archive.debian.org/debian buster main' \
      'deb http://archive.debian.org/debian-security buster/updates main' \
      > /etc/apt/sources.list \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends \
      crossbuild-essential-armhf make ca-certificates curl file \
 && rm -rf /var/lib/apt/lists/*

# mi-UGens needs CMake >= 3.19; Buster ships 3.13. CMake runs on the host arch.
ARG CMAKE_VERSION=3.31.6
RUN curl -fsSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" \
      | tar xz -C /opt \
 && ln -s /opt/cmake-${CMAKE_VERSION}-linux-x86_64/bin/* /usr/local/bin/

COPY toolchain-norns.cmake /opt/toolchain-norns.cmake
WORKDIR /work
