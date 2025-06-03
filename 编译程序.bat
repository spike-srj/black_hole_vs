@echo off
cls
echo ============================================
echo      Black Hole Demo - Build Script
echo ============================================
echo.

REM 清理旧文件
echo [1/3] Cleaning old files...
del *.o 2>nul
del blackhole_demo.exe 2>nul
echo      Done!
echo.

REM 编译
echo [2/3] Compiling...
echo.

REM 使用MSYS2编译，分步执行
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "echo 'Compiling ffimage.cpp...'; g++ -std=c++17 -I. -Iglm ffimage.cpp -c -o ffimage.o"
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "echo 'Compiling Camera.cpp...'; g++ -std=c++17 -I. -Iglm Camera.cpp -c -o Camera.o"
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "echo 'Compiling Shader.cpp...'; g++ -std=c++17 -I. -Iglm Shader.cpp -c -o Shader.o"
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "echo 'Compiling main_bh.cpp...'; g++ -std=c++17 -I. -Iglm main_bh.cpp -c -o main_bh.o"
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "echo 'Compiling glad_loader.c...'; gcc -c glad_loader.c -o glad_loader.o -I."
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "echo 'Linking...'; g++ ffimage.o Camera.o Shader.o main_bh.o glad_loader.o -o blackhole_demo.exe -lglfw3 -lopengl32 -lgdi32 -luser32 -lshell32"

echo.
echo [3/3] Copying runtime libraries...
copy "C:\msys64\mingw64\bin\libgcc_s_seh-1.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\libstdc++-6.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\libwinpthread-1.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\glfw3.dll" . >nul 2>&1
echo      Done!
echo.

REM 检查结果
if exist blackhole_demo.exe (
    echo ============================================
    echo BUILD SUCCESS!
    echo ============================================
    dir blackhole_demo.exe | findstr ".exe"
    echo.
    echo Next step: Run blackhole_demo.exe
) else (
    echo ============================================
    echo BUILD FAILED!
    echo ============================================
    echo Please check the error messages above.
)

echo.
pause 