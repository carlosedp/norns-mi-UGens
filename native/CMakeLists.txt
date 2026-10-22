# Build mi-UGens as native shared libraries, one per UGen, for programs that
# aren't SuperCollider (a plugin, a standalone app). See native/README.md.
#
#   cmake -S native -B build -DMI_SRC=work/mi-UGens -DCMAKE_BUILD_TYPE=Release
#   cmake --build build --config Release
#
# mi-UGens' own CMake files supply the source lists, as for wasm: SC_PATH points
# at the stand-in SC_PlugIn.h in wasm/include, and each UGen's MODULE target
# gets wasm/glue.cpp, so it exports the same C API the wasm builds do (mi_new,
# mi_next...). Each UGen stays its own library: their wrappers and Mutable
# Instruments' code would clash if linked into one.
cmake_minimum_required(VERSION 3.19)
if(APPLE AND NOT CMAKE_OSX_ARCHITECTURES)
  set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64" CACHE STRING "macOS architectures")  # universal, as mi-UGens does
endif()
project(mi-UGens-native CXX C)

set(MI_SRC "" CACHE PATH "mi-UGens source checkout (with its submodules)")
set(MI_UGENS MiPlaits MiRings MiRipples MiClouds MiBeads MiVerb MiElements CACHE STRING "UGens to build")
if(NOT EXISTS "${MI_SRC}/CMakeLists.txt")
  message(FATAL_ERROR "MI_SRC must point at a mi-UGens checkout (build.sh fetches one into work/mi-UGens)")
endif()

# libsamplerate (MiBraids') still declares an old cmake_minimum_required
set(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "" FORCE)
set(SHIM "${CMAKE_CURRENT_SOURCE_DIR}/../wasm")
set(SC_PATH "${SHIM}" CACHE PATH "" FORCE)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
# a UGen's internals stay inside its library; only glue.cpp's C API is exported
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
# Windows: the C runtime linked in, so the DLLs don't need a VC++ redistributable
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
if(APPLE AND NOT CMAKE_OSX_DEPLOYMENT_TARGET)
  set(CMAKE_OSX_DEPLOYMENT_TARGET 10.13 CACHE STRING "" FORCE)
endif()

add_subdirectory("${MI_SRC}" mi-UGens EXCLUDE_FROM_ALL)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64|amd64" AND NOT MSVC AND NOT APPLE)
  set(X86 ON)
endif()

foreach(u IN LISTS MI_UGENS)
  target_sources(${u} PRIVATE "${SHIM}/glue.cpp")
  target_include_directories(${u} PRIVATE "${SHIM}/include/plugin_interface")
  set_target_properties(${u} PROPERTIES
    PREFIX "" SUFFIX "${CMAKE_SHARED_LIBRARY_SUFFIX}" OUTPUT_NAME "${u}"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    LIBRARY_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/lib"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/lib")
  # Ripples includes VCV Rack's SSE vector code (simde on ARM)
  if(u STREQUAL "MiRipples" AND X86)
    target_compile_options(${u} PRIVATE -msse4.1)
  elseif(u STREQUAL "MiRipples" AND APPLE)
    target_compile_options(${u} PRIVATE "SHELL:-Xarch_x86_64 -msse4.1")  # universal: x86_64 half only
  endif()
  if(NOT MSVC AND NOT APPLE)
    # no surprises from the host's own symbols, or from libstdc++ versions
    target_link_options(${u} PRIVATE -Wl,-Bsymbolic -Wl,--exclude-libs,ALL -static-libstdc++ -static-libgcc)
  endif()
  list(APPEND MI_TARGETS ${u})
endforeach()
add_custom_target(mi-ugens ALL DEPENDS ${MI_TARGETS})

# renders each library and checks it makes sound (like wasm/test.mjs)
add_executable(mi-test test.cpp)
target_compile_features(mi-test PRIVATE cxx_std_17)
set_target_properties(mi-test PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}" RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}")
if(UNIX)
  target_link_libraries(mi-test PRIVATE ${CMAKE_DL_LIBS})
endif()
