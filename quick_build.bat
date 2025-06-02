@echo off
setlocal enabledelayedexpansion

echo ============================================
echo 黑洞演示项目快速构建脚本
echo ============================================

:: 检查必要工具
echo 检查编译环境...

:: 检查g++
g++ --version >nul 2>&1
if errorlevel 1 (
    echo 错误: 未找到g++编译器
    echo 请安装MinGW-w64或MSYS2
    echo 下载地址: https://www.msys2.org/
    pause
    exit /b 1
)
echo ✓ 找到g++编译器

:: 创建third_party目录
if not exist "third_party" mkdir third_party

:: 检查是否有GLFW库
if not exist "third_party\glfw" (
    echo 下载GLFW预编译库...
    
    :: 创建临时目录
    if not exist "temp" mkdir temp
    
    echo 请手动下载GLFW库:
    echo 1. 访问 https://www.glfw.org/download.html
    echo 2. 下载 "64-bit Windows binaries"
    echo 3. 解压到 third_party\glfw\ 目录
    echo 4. 确保目录结构为:
    echo    third_party\glfw\include\GLFW\
    echo    third_party\glfw\lib-mingw-w64\
    echo.
    echo 或者你可以使用包管理器安装GLFW
    
    pause
    echo 继续构建过程...
)

:: 修改Makefile以使用GLFW
echo 配置构建参数...

:: 检查GLFW是否存在
if exist "third_party\glfw\include\GLFW" (
    echo ✓ 找到GLFW库
    set GLFW_INCLUDES=-Ithird_party/glfw/include
    set GLFW_LIBS=-Lthird_party/glfw/lib-mingw-w64 -lglfw3
) else (
    echo ⚠ 未找到GLFW库，将尝试系统库
    set GLFW_INCLUDES=
    set GLFW_LIBS=-lglfw3
)

:: 编译项目
echo ============================================
echo 开始编译...
echo ============================================

:: 编译glad.c
echo 编译 glad.c...
gcc -c glad.c -o glad.o -I. -Iglm %GLFW_INCLUDES%
if errorlevel 1 (
    echo 错误: glad.c编译失败
    pause
    exit /b 1
)

:: 编译ffimage.cpp
echo 编译 ffimage.cpp...
g++ -std=c++17 -c ffimage.cpp -o ffimage.o -I. -Iglm %GLFW_INCLUDES%
if errorlevel 1 (
    echo 错误: ffimage.cpp编译失败
    pause
    exit /b 1
)

:: 编译Shader.cpp
echo 编译 Shader.cpp...
g++ -std=c++17 -c Shader.cpp -o Shader.o -I. -Iglm %GLFW_INCLUDES%
if errorlevel 1 (
    echo 错误: Shader.cpp编译失败
    pause
    exit /b 1
)

:: 编译Camera.cpp
echo 编译 Camera.cpp...
g++ -std=c++17 -c Camera.cpp -o Camera.o -I. -Iglm %GLFW_INCLUDES%
if errorlevel 1 (
    echo 错误: Camera.cpp编译失败
    pause
    exit /b 1
)

:: 编译main_bh.cpp
echo 编译 main_bh.cpp...
g++ -std=c++17 -c main_bh.cpp -o main_bh.o -I. -Iglm %GLFW_INCLUDES%
if errorlevel 1 (
    echo 错误: main_bh.cpp编译失败
    pause
    exit /b 1
)

:: 链接
echo 链接可执行文件...
g++ glad.o ffimage.o Shader.o Camera.o main_bh.o -o blackhole_demo.exe %GLFW_LIBS% -lopengl32 -lgdi32 -luser32 -lshell32
if errorlevel 1 (
    echo 错误: 链接失败
    echo 请确保GLFW库已正确安装
    pause
    exit /b 1
)

echo ============================================
echo ✓ 编译成功！
echo ============================================
echo.
echo 可执行文件: blackhole_demo.exe
echo.
echo 运行前请确保以下目录存在:
echo - shader/ (着色器文件)
echo - res/ (纹理资源)
echo.
echo 清理编译产物请运行: del *.o
echo.
pause 