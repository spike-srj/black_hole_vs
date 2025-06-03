@echo off
echo ============================================
echo 使用MinGW编译黑洞演示项目
echo ============================================

:: 设置编译器路径
set GCC=C:\msys64\mingw64\bin\gcc.exe
set GPP=C:\msys64\mingw64\bin\g++.exe

:: 设置包含目录
set INCLUDES=-I. -Iglm -IC:\msys64\mingw64\include

:: 设置库目录和链接库
set LIBS=-LC:\msys64\mingw64\lib -lglfw3 -lopengl32 -lgdi32 -luser32 -lshell32

echo 检查编译器...
%GPP% --version
if errorlevel 1 (
    echo 错误: 找不到g++编译器
    pause
    exit /b 1
)

echo.
echo 开始编译...
echo ============================================

:: 编译glad.c
echo 编译 glad.c...
%GCC% -c glad.c -o glad.o %INCLUDES%
if errorlevel 1 (
    echo 错误: glad.c编译失败
    pause
    exit /b 1
)

:: 编译ffimage.cpp
echo 编译 ffimage.cpp...
%GPP% -std=c++17 -c ffimage.cpp -o ffimage.o %INCLUDES%
if errorlevel 1 (
    echo 错误: ffimage.cpp编译失败
    pause
    exit /b 1
)

:: 编译Shader.cpp
echo 编译 Shader.cpp...
%GPP% -std=c++17 -c Shader.cpp -o Shader.o %INCLUDES%
if errorlevel 1 (
    echo 错误: Shader.cpp编译失败
    pause
    exit /b 1
)

:: 编译Camera.cpp
echo 编译 Camera.cpp...
%GPP% -std=c++17 -c Camera.cpp -o Camera.o %INCLUDES%
if errorlevel 1 (
    echo 错误: Camera.cpp编译失败
    pause
    exit /b 1
)

:: 编译main_bh.cpp
echo 编译 main_bh.cpp...
%GPP% -std=c++17 -c main_bh.cpp -o main_bh.o %INCLUDES%
if errorlevel 1 (
    echo 错误: main_bh.cpp编译失败
    pause
    exit /b 1
)

:: 链接
echo 链接可执行文件...
%GPP% glad.o ffimage.o Shader.o Camera.o main_bh.o -o blackhole_demo.exe %LIBS%
if errorlevel 1 (
    echo 错误: 链接失败
    pause
    exit /b 1
)

echo.
echo ============================================
echo ✓ 编译成功！
echo ============================================
echo.
echo 可执行文件: blackhole_demo.exe
echo.
echo 现在尝试运行程序...
echo.

:: 尝试运行程序
.\blackhole_demo.exe 