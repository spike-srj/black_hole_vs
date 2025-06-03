@echo off
chcp 65001 >nul 2>&1
cls
echo ============================================
echo      黑洞演示程序 - 快速编译脚本
echo ============================================
echo.

REM 清理旧文件
echo [1/3] 清理旧文件...
del *.o >nul 2>&1
del blackhole_demo.exe >nul 2>&1
echo      √ 清理完成
echo.

REM 编译
echo [2/3] 开始编译...
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "
g++ -std=c++17 -I. -Iglm ffimage.cpp Camera.cpp Shader.cpp main_bh.cpp -c;
gcc -c glad_loader.c -o glad_loader.o -I.;
g++ *.o -o blackhole_demo.exe -lglfw3 -lopengl32 -lgdi32 -luser32 -lshell32;
"

echo.
echo [3/3] 复制运行库...
copy "C:\msys64\mingw64\bin\libgcc_s_seh-1.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\libstdc++-6.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\libwinpthread-1.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\glfw3.dll" . >nul 2>&1
echo      √ 运行库复制完成
echo.

REM 检查结果
if exist blackhole_demo.exe (
    echo ============================================
    echo ✅ 编译成功！
    echo ============================================
    dir blackhole_demo.exe | findstr ".exe"
    echo.
    echo 下一步：运行 一键运行.bat 启动程序
) else (
    echo ============================================
    echo ❌ 编译失败！
    echo ============================================
    echo 请检查上面的错误信息
)

echo.
pause 