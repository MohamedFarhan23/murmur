cmake_minimum_required(VERSION 3.22.1)
project(murmur CXX)

# Prebuilt Needle engine (Cactus-Compute/needle3 on Hugging Face), one folder per ABI.
set(NEEDLE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../third_party/needle)

if(ANDROID_ABI STREQUAL "arm64-v8a")
  set(NEEDLE_PLATFORM android-arm64)
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
  set(NEEDLE_PLATFORM android-armv7)
else()
  # Flutter debug builds also target x86_64 emulators, which Needle doesn't ship.
  message(WARNING "No Needle engine build for ${ANDROID_ABI}; skipping libmurmur")
  return()
endif()

# libmurmur.so is libneedle.a re-exported whole, so Dart can look up every
# needle_* symbol with DynamicLibrary.open("libmurmur.so").
add_library(murmur SHARED murmur.cpp)
target_include_directories(murmur PRIVATE ${NEEDLE_DIR}/${NEEDLE_PLATFORM})
target_link_libraries(murmur PRIVATE
  -Wl,--whole-archive ${NEEDLE_DIR}/${NEEDLE_PLATFORM}/libneedle.a -Wl,--no-whole-archive
  m)
