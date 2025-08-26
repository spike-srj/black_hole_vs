cmake_minimum_required(VERSION 3.16)
project(blackhole_demo LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Sources and headers
set(SOURCES
    src/main_bh.cpp
    src/Shader.cpp
    src/Camera.cpp
    src/ffimage.cpp
    src/glad_loader.c
)

set(HEADERS
    include/Base.h
    include/Shader.h
    include/Camera.h
    include/ffImage.h
    include/stb_image.h
)

add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS})

# Include directories
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/external
)

# Find system OpenGL
find_package(OpenGL REQUIRED)

# Platform-specific config
if(WIN32)
    # Optional prebuilt GLFW under third_party/glfw
    set(GLFW_ROOT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/third_party/glfw")
    if(EXISTS "${GLFW_ROOT_PATH}")
        target_include_directories(${PROJECT_NAME} PRIVATE "${GLFW_ROOT_PATH}/include")
        target_link_directories(${PROJECT_NAME} PRIVATE "${GLFW_ROOT_PATH}/lib")
        target_link_libraries(${PROJECT_NAME} PRIVATE glfw3)
    else()
        find_package(glfw3 QUIET)
        if(glfw3_FOUND)
            target_link_libraries(${PROJECT_NAME} PRIVATE glfw)
        else()
            message(WARNING "GLFW not found. Please install GLFW using vcpkg or provide it in third_party/glfw")
        endif()
    endif()
    target_link_libraries(${PROJECT_NAME} PRIVATE opengl32 gdi32 user32 shell32)
else()
    find_package(glfw3 REQUIRED)
    target_link_libraries(${PROJECT_NAME} PRIVATE glfw)
endif()

# Link OpenGL
target_link_libraries(${PROJECT_NAME} PRIVATE OpenGL::GL)

# Compiler options
if(MSVC)
    target_compile_definitions(${PROJECT_NAME} PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_compile_options(${PROJECT_NAME} PRIVATE /W3)
else()
    target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra)
endif()

# Output dir
set_target_properties(${PROJECT_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

# Copy resources after build
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${CMAKE_SOURCE_DIR}/shader ${CMAKE_BINARY_DIR}/bin/shader
)

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${CMAKE_SOURCE_DIR}/res ${CMAKE_BINARY_DIR}/bin/res
)

message(STATUS "Project: ${PROJECT_NAME}")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")
