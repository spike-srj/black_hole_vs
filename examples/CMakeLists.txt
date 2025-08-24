cmake_minimum_required(VERSION 3.16)

# Helper to add an example quickly
function(add_blackhole_example NAME SRC)
    add_executable(${NAME} ${SRC})
    target_link_libraries(${NAME} PRIVATE blackhole_core OpenGL::GL glfw)

    if(MSVC)
        target_compile_options(${NAME} PRIVATE /W3)
    else()
        target_compile_options(${NAME} PRIVATE -Wall -Wextra)
    endif()

    set_target_properties(${NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
    add_custom_command(TARGET ${NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_SOURCE_DIR}/shader ${CMAKE_BINARY_DIR}/bin/shader)
    add_custom_command(TARGET ${NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_SOURCE_DIR}/res ${CMAKE_BINARY_DIR}/bin/res)
endfunction()

# Examples can be added like this after migrating files to examples/:
# add_blackhole_example(example_main0 ${CMAKE_SOURCE_DIR}/examples/main0.cpp)
# add_blackhole_example(example_openGLFW ${CMAKE_SOURCE_DIR}/examples/openGLFW.cpp)

