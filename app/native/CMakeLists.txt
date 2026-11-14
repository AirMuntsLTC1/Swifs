cmake_minimum_required(VERSION 3.18)
project(swifs_core CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(swifs_core SHARED src/swifs_core.cpp)
target_include_directories(swifs_core PRIVATE include)


