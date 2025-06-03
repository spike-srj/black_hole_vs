@echo off
chcp 65001 >nul 2>&1
cls
echo ============================================
echo      黑洞引力透镜演示 - 一键运行脚本
echo ============================================
echo.

REM 检查并复制所有必要的DLL
echo [1/2] 正在检查运行环境...
if not exist "libgcc_s_seh-1.dll" (
    copy "C:\msys64\mingw64\bin\libgcc_s_seh-1.dll" . >nul 2>&1
    echo      √ 复制 libgcc_s_seh-1.dll
)
if not exist "libstdc++-6.dll" (
    copy "C:\msys64\mingw64\bin\libstdc++-6.dll" . >nul 2>&1
    echo      √ 复制 libstdc++-6.dll
)
if not exist "libwinpthread-1.dll" (
    copy "C:\msys64\mingw64\bin\libwinpthread-1.dll" . >nul 2>&1
    echo      √ 复制 libwinpthread-1.dll
)
if not exist "glfw3.dll" (
    copy "C:\msys64\mingw64\bin\glfw3.dll" . >nul 2>&1
    echo      √ 复制 glfw3.dll
)

echo      √ 运行环境准备完成
echo.

REM 检查可执行文件
if not exist "blackhole_demo.exe" (
    echo ❌ 错误：找不到 blackhole_demo.exe
    echo    请先运行 快速编译.bat 编译程序
    echo.
    pause
    exit /b 1
)

echo [2/2] 启动黑洞演示程序...
echo.
echo ============================================
echo 控制说明：
echo   • ESC键 - 退出程序
echo   • 鼠标  - 视角控制
echo   • WASD  - 移动控制（如果支持）
echo ============================================
echo.

REM 直接运行程序
start "" blackhole_demo.exe

echo.
echo 程序已启动！
echo 如果看不到窗口，请检查任务栏。
echo.
pause 