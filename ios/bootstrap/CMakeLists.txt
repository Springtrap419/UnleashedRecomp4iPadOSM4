cmake_minimum_required(VERSION 3.24)

project(UnleashedRecompIOSBootstrap LANGUAGES C CXX OBJC OBJCXX)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(FATAL_ERROR "This bootstrap target must be configured for iOS (CMAKE_SYSTEM_NAME=iOS).")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(UnleashedRecompIOSBootstrap MACOSX_BUNDLE
    main.mm
)

target_compile_options(UnleashedRecompIOSBootstrap PRIVATE -fobjc-arc)

target_link_libraries(UnleashedRecompIOSBootstrap PRIVATE
    "-framework UIKit"
    "-framework Metal"
    "-framework MetalKit"
    "-framework QuartzCore"
)

set_target_properties(UnleashedRecompIOSBootstrap PROPERTIES
    OUTPUT_NAME "Unleashed iPad Test"
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.springtrap419.unleashedrecomp.bootstrap"
    MACOSX_BUNDLE_BUNDLE_NAME "Unleashed iPad Test"
    MACOSX_BUNDLE_BUNDLE_VERSION "1"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "0.1"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.springtrap419.unleashedrecomp.bootstrap"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "17.0"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
)
