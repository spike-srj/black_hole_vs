@echo off
echo ============================================
echo 黑洞演示项目构建测试
echo ============================================

:: 检查必要文件
echo 检查项目文件...

if not exist "CMakeLists.txt" (
    echo ❌ 缺少 CMakeLists.txt
    exit /b 1
)
echo ✓ CMakeLists.txt 存在

if not exist "main_bh.cpp" (
    echo ❌ 缺少 main_bh.cpp
    exit /b 1
)
echo ✓ main_bh.cpp 存在

if not exist "shader" (
    echo ❌ 缺少 shader 目录
    exit /b 1
)
echo ✓ shader 目录存在

if not exist "res" (
    echo ❌ 缺少 res 目录
    exit /b 1
)
echo ✓ res 目录存在

if not exist "glm" (
    echo ❌ 缺少 glm 目录
    exit /b 1
)
echo ✓ glm 目录存在

:: 检查关键着色器文件
if not exist "shader\blackholev.glsl" (
    echo ❌ 缺少 blackholev.glsl
    exit /b 1
)
echo ✓ blackholev.glsl 存在

if not exist "shader\blackholef.glsl" (
    echo ❌ 缺少 blackholef.glsl
    exit /b 1
)
echo ✓ blackholef.glsl 存在

:: 检查资源文件
if not exist "res\skybox3" (
    echo ❌ 缺少 skybox3 目录
    exit /b 1
)
echo ✓ skybox3 目录存在

echo.
echo ============================================
echo ✓ 项目文件检查完成！
echo ============================================
echo.
echo 项目已准备就绪，可以进行构建。
echo.
echo 构建方法：
echo 1. 使用 CMake: 运行 setup.bat
echo 2. 使用 MinGW: 运行 quick_build.bat
echo 3. 使用 VS Code: 打开项目文件夹并按 Ctrl+Shift+P，选择 "CMake: Build"
echo.
pause