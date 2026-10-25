# The Dream toolchain's build, from the repository's root. The VM is the only
# part CMake builds; the compiler, mind and the language server are images the
# VM makes from their sources (ci/images.sh). The components are submodules at
# the paths the Dream workspace (github.com/Custards1/dream) has them, so every
# relative path in them works here as it does there.
cmake_minimum_required(VERSION 3.20)
project(dream LANGUAGES CXX)
include(CTest)
add_subdirectory(dream)
