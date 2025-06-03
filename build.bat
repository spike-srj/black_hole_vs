@echo off
echo Building Black Hole Demo...
echo.

REM 删除旧文件
del *.o 2>nul
del blackhole_demo.exe 2>nul

REM 在MSYS2中执行所有编译命令
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "g++ -std=c++17 -I. -Iglm ffimage.cpp Camera.cpp Shader.cpp main_bh.cpp -c && gcc -c glad_loader.c -o glad_loader.o -I. && g++ *.o -o blackhole_demo.exe -lglfw3 -lopengl32 -lgdi32 -luser32 -lshell32 && echo 'Build completed!'"

REM 复制DLL
copy "C:\msys64\mingw64\bin\libgcc_s_seh-1.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\libstdc++-6.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\libwinpthread-1.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\glfw3.dll" . >nul 2>&1

REM 检查结果
if exist blackhole_demo.exe (
    echo.
    echo SUCCESS! blackhole_demo.exe created.
    dir blackhole_demo.exe | findstr ".exe"
) else (
    echo.
    echo FAILED! Check errors above.
)

echo.
pause 