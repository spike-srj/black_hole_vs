@echo off
echo 正在设置黑洞演示项目...

:: 检查是否已安装CMake
cmake --version >nul 2>&1
if errorlevel 1 (
    echo 错误: 未找到CMake，请先安装CMake 3.16+
    pause
    exit /b 1
)

:: 检查是否存在vcpkg
if exist "vcpkg" (
    echo 找到vcpkg目录
) else (
    echo 正在下载vcpkg...
    git clone https://github.com/Microsoft/vcpkg.git
    if errorlevel 1 (
        echo 错误: 无法下载vcpkg
        pause
        exit /b 1
    )
)

:: 初始化vcpkg
if not exist "vcpkg\vcpkg.exe" (
    echo 正在初始化vcpkg...
    cd vcpkg
    call bootstrap-vcpkg.bat
    if errorlevel 1 (
        echo 错误: vcpkg初始化失败
        pause
        exit /b 1
    )
    cd ..
)

:: 安装GLFW
echo 正在安装GLFW...
vcpkg\vcpkg install glfw3:x64-windows
if errorlevel 1 (
    echo 警告: GLFW安装失败，将尝试其他方式
)

:: 创建构建目录
if not exist "build" mkdir build

:: 配置项目
echo 正在配置项目...
cd build
cmake -DCMAKE_TOOLCHAIN_FILE=..\vcpkg\scripts\buildsystems\vcpkg.cmake ..
if errorlevel 1 (
    echo 错误: CMake配置失败
    cd ..
    pause
    exit /b 1
)

:: 构建项目
echo 正在构建项目...
cmake --build . --config Release
if errorlevel 1 (
    echo 错误: 项目构建失败
    cd ..
    pause
    exit /b 1
)

cd ..
echo.
echo 项目设置完成！
echo 可执行文件位于: build\bin\blackhole_demo.exe
echo.
pause 