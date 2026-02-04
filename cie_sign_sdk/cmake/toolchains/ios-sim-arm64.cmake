set(CMAKE_SYSTEM_NAME iOS)

execute_process(
    COMMAND xcrun --sdk iphonesimulator --show-sdk-path
    OUTPUT_VARIABLE IOS_SIM_SDK_PATH
    OUTPUT_STRIP_TRAILING_WHITESPACE)

if(NOT IOS_SIM_SDK_PATH)
    message(FATAL_ERROR "Unable to locate iPhoneSimulator SDK. Ensure Xcode is installed.")
endif()

set(CMAKE_OSX_SYSROOT "${IOS_SIM_SDK_PATH}" CACHE PATH "" FORCE)
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "" FORCE)
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "" FORCE)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)
