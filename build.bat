@echo off
setlocal

REM Ensure working directory is this script's directory
pushd "%~dp0"

echo Building Black Hole Demo (MSYS2 MinGW64)...

REM MSYS2 root (change if different)
set MSYS2=C:\msys64
set MINGW_BIN=%MSYS2%\mingw64\bin

REM Prepare output dirs
if not exist bin mkdir bin

REM Pre-sync resources (so edits are visible even if post-step is skipped)
echo [RES] Pre-sync shader/ and res/ into bin/
where robocopy >nul 2>&1
if %ERRORLEVEL%==0 (
  if exist shader robocopy shader bin\shader /E /NFL /NDL /NJH /NJS /NC /NS >nul
  if exist res    robocopy res    bin\res    /E /NFL /NDL /NJH /NJS /NC /NS >nul
) else (
  if exist shader xcopy /E /I /Y shader bin\shader >nul
  if exist res    xcopy /E /I /Y res    bin\res    >nul
)

REM Build inside MSYS2 MinGW64 shell
"%MSYS2%\msys2_shell.cmd" -defterm -here -no-start -mingw64 -c "mkdir -p build/obj && g++ -std=c++17 -Iinclude -Iexternal -Ithird_party/glfw/include -c src/ffimage.cpp -o build/obj/ffimage.o && g++ -std=c++17 -Iinclude -Iexternal -Ithird_party/glfw/include -c src/Camera.cpp -o build/obj/Camera.o && g++ -std=c++17 -Iinclude -Iexternal -Ithird_party/glfw/include -c src/Shader.cpp -o build/obj/Shader.o && g++ -std=c++17 -Iinclude -Iexternal -Ithird_party/glfw/include -c src/main_bh.cpp -o build/obj/main_bh.o && gcc -Iinclude -Iexternal -Ithird_party/glfw/include -c src/glad_loader.c -o build/obj/glad.o && g++ build/obj/*.o -Lthird_party/glfw/lib -o bin/blackhole_demo.exe -lglfw3 -lopengl32 -lgdi32 -luser32 -lshell32 && echo Build completed!"

REM Post-sync resources (redundant but safe)
echo [RES] Post-sync shader/ and res/ into bin/
where robocopy >nul 2>&1
if %ERRORLEVEL%==0 (
  if exist shader robocopy shader bin\shader /E /NFL /NDL /NJH /NJS /NC /NS >nul
  if exist res    robocopy res    bin\res    /E /NFL /NDL /NJH /NJS /NC /NS >nul
) else (
  if exist shader xcopy /E /I /Y shader bin\shader >nul
  if exist res    xcopy /E /I /Y res    bin\res    >nul
)

REM Copy runtime DLLs (from MSYS2)
copy "%MINGW_BIN%\libgcc_s_seh-1.dll" bin >nul 2>&1
copy "%MINGW_BIN%\libstdc++-6.dll"   bin >nul 2>&1
copy "%MINGW_BIN%\libwinpthread-1.dll" bin >nul 2>&1
copy "%MINGW_BIN%\glfw3.dll"         bin >nul 2>&1

REM Copy vendor GLFW DLL if provided
if exist third_party\glfw\bin\glfw3.dll copy third_party\glfw\bin\glfw3.dll bin >nul 2>&1

REM Summary
echo.
if exist bin\blackhole_demo.exe (
  echo SUCCESS! bin\blackhole_demo.exe created.
) else (
  echo FAILED! Ensure MSYS2 MinGW64 is installed at %MSYS2% and GLFW is available.
)

echo Resources:
if exist bin\shader echo  - shader: OK
if exist bin\res    echo  - res:    OK

popd
endlocal
