@echo off
echo ============================================
echo         重新编译黑洞演示程序
echo ============================================
echo.
echo 正在清理旧的目标文件...
del *.o 2>nul
del blackhole_demo.exe 2>nul

echo.
echo 正在使用MSYS2/MinGW重新编译...
echo.

REM 切换到MSYS2环境并编译
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "
echo '1. 编译 ffimage.cpp...';
g++ -std=c++17 -I. -Iglm ffimage.cpp -c -o ffimage.o;
echo '2. 编译 Camera.cpp...';
g++ -std=c++17 -I. -Iglm Camera.cpp -c -o Camera.o;
echo '3. 编译 Shader.cpp...';
g++ -std=c++17 -I. -Iglm Shader.cpp -c -o Shader.o;
echo '4. 编译 main_bh.cpp...';
g++ -std=c++17 -I. -Iglm main_bh.cpp -c -o main_bh.o;
echo '5. 编译 glad_loader.c...';
gcc -c glad_loader.c -o glad_loader.o -I.;
echo '6. 链接生成可执行文件...';
g++ ffimage.o Camera.o Shader.o main_bh.o glad_loader.o -o blackhole_demo.exe -lglfw3 -lopengl32 -lgdi32 -luser32 -lshell32;
echo '编译完成！';
"

echo.
echo 正在复制运行时库...
copy "C:\msys64\mingw64\bin\libgcc_s_seh-1.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\libstdc++-6.dll" . >nul 2>&1  
copy "C:\msys64\mingw64\bin\libwinpthread-1.dll" . >nul 2>&1
copy "C:\msys64\mingw64\bin\libglfw-3.dll" . >nul 2>&1

echo.
if exist blackhole_demo.exe (
    echo ✅ 编译成功！可执行文件已生成。
    echo 📁 文件大小：
    dir blackhole_demo.exe | findstr ".exe"
    echo.
    echo 🚀 现在可以运行程序了：
    echo    .\blackhole_demo.exe
    echo    或者
    echo    .\start_blackhole.bat
) else (
    echo ❌ 编译失败！请检查错误信息。
)

echo.
pause 