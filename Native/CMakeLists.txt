cmake_minimum_required(VERSION 3.21)

# Set vcpkg triplet before project() if not already set
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE AND DEFINED ENV{VCPKG_ROOT})
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

# Use static linking for release builds (smaller distribution)
if(NOT DEFINED VCPKG_TARGET_TRIPLET)
    set(VCPKG_TARGET_TRIPLET "x64-windows-static" CACHE STRING "")
endif()

project(
    SeverActionsNative
    VERSION 1.0.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Only enable IPO for release builds
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
endif()

# CommonLibSSE-NG
find_package(CommonLibSSE CONFIG REQUIRED)

# nlohmann_json for JSON parsing (crafting/travel databases)
find_package(nlohmann_json CONFIG REQUIRED)

# Plugin configuration
set(PLUGIN_NAME "${PROJECT_NAME}")
set(PLUGIN_AUTHOR "Severause")
set(PLUGIN_VERSION "${PROJECT_VERSION}")

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/version.rc.in
    ${CMAKE_CURRENT_BINARY_DIR}/version.rc
    @ONLY
)

# Source files
# Note: SkyrimNetAPI and NativeActions removed - simplified architecture
# Native C++ provides database lookups and workstation finding only
# All action execution goes through YAML -> Papyrus -> native functions
set(SOURCES
    src/main.cpp
    src/plugin.cpp
    src/papyrus.cpp
    src/FurnitureManager.cpp
    src/SandboxManager.cpp
    src/DialogueAnimManager.cpp
    src/SurvivalUtils.cpp
    src/YieldMonitor.cpp
    src/TeammateMonitor.cpp
    src/OrphanCleanup.cpp
)

set(HEADERS
    src/plugin.h
    src/papyrus.h
    src/StringUtils.h
    src/CraftingDB.h
    src/TravelDB.h
    src/LocationResolver.h
    src/ActorFinder.h
    src/StuckDetector.h
    src/InventoryUtils.h
    src/NearbySearch.h
    src/FurnitureManager.h
    src/SandboxManager.h
    src/DialogueAnimManager.h
    src/FertilityMode.h
    src/RecipeDB.h
    src/AlchemyDB.h
    src/SurvivalUtils.h
    src/NsfwUtils.h
    src/BookUtils.h
    src/CrimeUtils.h
    src/CollisionUtils.h
    src/DBFBridge.h
    src/YieldMonitor.h
    src/OffScreenTracker.h
    src/TeammateMonitor.h
    src/OrphanCleanup.h
)

# Create DLL
add_library(${PROJECT_NAME} SHARED
    ${SOURCES}
    ${HEADERS}
    ${CMAKE_CURRENT_BINARY_DIR}/version.rc
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
    PLUGIN_NAME="${PLUGIN_NAME}"
    PLUGIN_AUTHOR="${PLUGIN_AUTHOR}"
    PLUGIN_VERSION="${PLUGIN_VERSION}"
    # Silence some warnings from CommonLibSSE
    _SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING
)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    CommonLibSSE::CommonLibSSE
    nlohmann_json::nlohmann_json
)

# MSVC specific settings
if(MSVC)
    target_compile_options(${PROJECT_NAME} PRIVATE
        /W4         # Warning level 4
        /WX-        # Don't treat warnings as errors (CommonLibSSE has some)
        /permissive-
        /Zc:preprocessor
        /external:anglebrackets
        /external:W0
    )

    # Use static runtime to match vcpkg x64-windows-static libraries
    set_property(TARGET ${PROJECT_NAME} PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
    )
endif()

# Output directory
set_target_properties(${PROJECT_NAME} PROPERTIES
    OUTPUT_NAME "${PLUGIN_NAME}"
    SUFFIX ".dll"
)

# Copy TOML file alongside DLL after build
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/SeverActionsNative.toml"
        "$<TARGET_FILE_DIR:${PROJECT_NAME}>/SeverActionsNative.toml"
    COMMENT "Copying TOML configuration file"
)

# Optional: Copy to Skyrim SKSE plugins folder if SKYRIM_DIR is set
if(DEFINED ENV{SKYRIM_DIR})
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:${PROJECT_NAME}>"
            "$ENV{SKYRIM_DIR}/Data/SKSE/Plugins/${PLUGIN_NAME}.dll"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/SeverActionsNative.toml"
            "$ENV{SKYRIM_DIR}/Data/SKSE/Plugins/SeverActionsNative.toml"
        COMMENT "Deploying to Skyrim SKSE/Plugins folder"
    )
endif()

# Print configuration summary
message(STATUS "")
message(STATUS "=== ${PROJECT_NAME} Configuration ===")
message(STATUS "Version: ${PROJECT_VERSION}")
message(STATUS "Author: ${PLUGIN_AUTHOR}")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "")
