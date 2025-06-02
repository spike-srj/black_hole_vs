cmake_minimum_required(VERSION 3.16)
project(blackhole_demo LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 添加源文件
set(SOURCES
    main_bh.cpp
    Shader.cpp
    Camera.cpp
    ffimage.cpp
    glad.c
)

set(HEADERS
    Base.h
    Shader.h
    Camera.h
    ffimage.h
    stb_image.h
)

# 创建可执行文件
add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS})

# 设置包含目录
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/glm
)

# 寻找系统级的依赖库
find_package(OpenGL REQUIRED)

# Windows平台特定配置
if(WIN32)
    # 检查是否存在预编译的GLFW库
    set(GLFW_ROOT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/third_party/glfw")
    
    if(EXISTS "${GLFW_ROOT_PATH}")
        # 使用项目内部的GLFW
        target_include_directories(${PROJECT_NAME} PRIVATE "${GLFW_ROOT_PATH}/include")
        target_link_directories(${PROJECT_NAME} PRIVATE "${GLFW_ROOT_PATH}/lib")
        target_link_libraries(${PROJECT_NAME} PRIVATE glfw3)
    else()
        # 尝试使用vcpkg或系统GLFW
        find_package(glfw3 QUIET)
        if(glfw3_FOUND)
            target_link_libraries(${PROJECT_NAME} PRIVATE glfw)
        else()
            message(WARNING "GLFW not found. Please install GLFW using vcpkg or provide it in third_party/glfw")
        endif()
    endif()
    
    # Windows系统库
    target_link_libraries(${PROJECT_NAME} PRIVATE opengl32 gdi32 user32 shell32)
    
else()
    # Linux/macOS配置
    find_package(glfw3 REQUIRED)
    target_link_libraries(${PROJECT_NAME} PRIVATE glfw)
endif()

# 链接OpenGL
target_link_libraries(${PROJECT_NAME} PRIVATE OpenGL::GL)

# 编译器特定设置
if(MSVC)
    target_compile_definitions(${PROJECT_NAME} PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_compile_options(${PROJECT_NAME} PRIVATE /W3)
else()
    target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra)
endif()

# 设置输出目录
set_target_properties(${PROJECT_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

# 复制资源文件到构建目录
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