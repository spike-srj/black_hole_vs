@echo off
echo 正在复制必要的运行时库...

REM 复制MinGW运行时库
copy "C:\msys64\mingw64\bin\libgcc_s_seh-1.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\libstdc++-6.dll" . >nul 2>&1  
copy "C:\msys64\mingw64\bin\libwinpthread-1.dll" . >nul 2>&1

REM 复制GLFW库
copy "C:\msys64\mingw64\bin\libglfw-3.dll" . >nul 2>&1

echo 运行时库复制完成！
echo 现在可以直接运行 blackhole_demo.exe 了
echo.
pause 