cmake_minimum_required(VERSION 3.22)
project(cie_sign_mobile LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT DEFINED DEPENDENCIES_DIR)
    message(FATAL_ERROR "DEPENDENCIES_DIR is not set. Run build_android_dependencies.sh first.")
endif()

if(NOT DEFINED CIE_SIGN_SDK_SKIP_TESTS)
    set(CIE_SIGN_SDK_SKIP_TESTS OFF)
endif()

set(CIE_SIGN_SDK_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../cie_sign_sdk)

add_definitions(-DANDROID)

add_subdirectory(${CIE_SIGN_SDK_ROOT} ${CMAKE_BINARY_DIR}/cie_sign_sdk_build)

find_library(log-lib log)
find_library(android-lib android)

add_library(ciesign_mobile SHARED
    mock_sign_android.cpp
    nfc_sign_android.cpp
    ${CIE_SIGN_SDK_ROOT}/tests/mock/mock_apdu_sequence.cpp
    ${CIE_SIGN_SDK_ROOT}/tests/mock/mock_transport.cpp
)

target_include_directories(ciesign_mobile
    PRIVATE
        ${CIE_SIGN_SDK_ROOT}/include
        ${CIE_SIGN_SDK_ROOT}/src
        ${CIE_SIGN_SDK_ROOT}/tests
)

get_target_property(CIE_SIGN_SDK_PRIVATE_INCLUDES cie_sign_sdk INCLUDE_DIRECTORIES)
if(CIE_SIGN_SDK_PRIVATE_INCLUDES)
    target_include_directories(ciesign_mobile PRIVATE ${CIE_SIGN_SDK_PRIVATE_INCLUDES})
endif()

target_link_libraries(ciesign_mobile
    PRIVATE
        ciesign_core
        ${log-lib}
        ${android-lib}
)
