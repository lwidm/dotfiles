cmake_minimum_required(VERSION 3.15)

project(EWW_Scripts VERSION 1.0)

add_library(EWWScripts_compiler_flags INTERFACE)
target_compile_features(EWWScripts_compiler_flags INTERFACE cxx_std_11)

# add compiler warning flags just when building this project via the
# BUILD_INTERFACE genex
set(gcc_like_cxx "$<COMPILE_LANG_AND_ID:CXX,ARMClang,AppleClang,Clang,GNU,LCC>")
set(msvc_cxx "$<COMPILE_LANG_AND_ID:CXX,MSVC>")
target_compile_options(
  EWWScripts_compiler_flags
  INTERFACE
    "$<${gcc_like_cxx}:$<BUILD_INTERFACE:-Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>>"
    "$<${msvc_cxx}:$<BUILD_INTERFACE:-W3>>")

add_subdirectory(src)

# installation Preserve RPATH in the installed binaries
set(CMAKE_INSTALL_PREFIX "${CMAKE_SOURCE_DIR}")
set(CMAKE_INSTALL_RPATH "${CMAKE_SOURCE_DIR}/lib")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
message(STATUS "DEBUGGING_TOP: ${CMAKE_INSTALL_RPATH}")
