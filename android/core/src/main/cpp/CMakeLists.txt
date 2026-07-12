cmake_minimum_required(VERSION 3.22.1)

project("core")

message("CMAKE_SOURCE_DIR ${CMAKE_SOURCE_DIR}")

message("CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE}")

if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    add_compile_options(-O3 -flto -g0 -fno-exceptions -fno-rtti)
    add_link_options(-flto -Wl,--gc-sections,--strip-all)
endif ()

set(LIB_MIHOMO_PATH "${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libmihomo.so")

message("LIB_MIHOMO_PATH ${LIB_MIHOMO_PATH}")
if (EXISTS ${LIB_MIHOMO_PATH})
    message("Found libmihomo.so for ABI ${ANDROID_ABI}")
    add_compile_definitions(LIBMIHOMO)
    include_directories(${CMAKE_SOURCE_DIR}/../cpp/includes/${ANDROID_ABI})
    link_directories(${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})
    add_library(${CMAKE_PROJECT_NAME} SHARED
            jni_helper.cpp
            core.cpp)
    target_link_libraries(${CMAKE_PROJECT_NAME}
            mihomo)
else ()
    message("Not found libmihomo.so for ABI ${ANDROID_ABI}")
    add_library(${CMAKE_PROJECT_NAME} SHARED
            jni_helper.cpp
            core.cpp)
    target_link_libraries(${CMAKE_PROJECT_NAME})
endif ()