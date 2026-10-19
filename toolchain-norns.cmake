# CMake toolchain for cross-compiling SuperCollider plugins for monome norns.
#
# norns (CM3/CM3+), norns shield (Pi 3B/3B+/4) all have Cortex-A53/A72 cores and
# run a 32-bit armhf userland, so we target ARMv8 in AArch32 mode with NEON.
# Override with -DNORNS_ARCH_FLAGS="..." if needed.
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR armv7l)

set(CROSS_PREFIX arm-linux-gnueabihf-)
set(CMAKE_C_COMPILER   ${CROSS_PREFIX}gcc)
set(CMAKE_CXX_COMPILER ${CROSS_PREFIX}g++)
set(CMAKE_STRIP        ${CROSS_PREFIX}strip)

set(NORNS_ARCH_FLAGS "-mcpu=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard"
    CACHE STRING "CPU flags for the norns target")

set(CMAKE_C_FLAGS_INIT   "${NORNS_ARCH_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${NORNS_ARCH_FLAGS}")

set(CMAKE_FIND_ROOT_PATH /usr/arm-linux-gnueabihf)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
