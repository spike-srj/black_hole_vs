@echo off
cls
echo ============================================
echo      Black Hole Demo - Run Script
echo ============================================
echo.

REM 检查并复制所有必要的DLL
echo [1/2] Checking runtime environment...
set need_copy=0

if not exist "libgcc_s_seh-1.dll" (
    copy "C:\msys64\mingw64\bin\libgcc_s_seh-1.dll" . >nul 2>&1
    echo      + Copied libgcc_s_seh-1.dll
    set need_copy=1
)
if not exist "libstdc++-6.dll" (
    copy "C:\msys64\mingw64\bin\libstdc++-6.dll" . >nul 2>&1
    echo      + Copied libstdc++-6.dll
    set need_copy=1
)
if not exist "libwinpthread-1.dll" (
    copy "C:\msys64\mingw64\bin\libwinpthread-1.dll" . >nul 2>&1
    echo      + Copied libwinpthread-1.dll
    set need_copy=1
)
if not exist "glfw3.dll" (
    copy "C:\msys64\mingw64\bin\glfw3.dll" . >nul 2>&1
    echo      + Copied glfw3.dll
    set need_copy=1
)

if %need_copy%==0 (
    echo      All runtime libraries are ready!
) else (
    echo      Runtime libraries copied successfully!
)
echo.

REM 检查可执行文件
if not exist "blackhole_demo.exe" (
    echo ERROR: blackhole_demo.exe not found!
    echo Please run "编译程序.bat" first to build the program.
    echo.
    pause
    exit /b 1
)

echo [2/2] Starting Black Hole Demo...
echo.
echo ============================================
echo Controls:
echo   - ESC   : Exit program
echo   - Mouse : Camera control
echo   - WASD  : Movement (if supported)
echo ============================================
echo.

REM 直接运行程序
echo Launching program...
start "" blackhole_demo.exe

echo.
echo Program launched!
echo Check the taskbar if you don't see the window.
echo.
pause 