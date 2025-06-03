@echo off
echo 正在MSYS2环境中运行程序（可以看到控制台输出）...
echo.
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "./blackhole_demo.exe"
echo.
pause 