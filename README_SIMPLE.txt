==================================================
        BLACK HOLE DEMO - QUICK START
==================================================

STEP 1: BUILD
   Double click → build.bat

STEP 2: RUN
   Double click → 运行程序.bat

That's it!

==================================================

PROJECT FILES:

ESSENTIAL:
• build.bat          - Build the program
• 运行程序.bat       - Run the program  
• blackhole_demo.exe - The program (generated)
• README_SIMPLE.txt  - This guide

SOURCE CODE:
• main_bh.cpp        - Main program
• Camera.cpp/h       - Camera system
• Shader.cpp/h       - Shader management
• ffimage.cpp/h      - Image loading
• glad_loader.c      - OpenGL loader
• shader/            - GLSL shaders
• res/               - Textures/assets

==================================================

FOR DEVELOPERS:

1. Edit source code files
2. Run build.bat to rebuild
3. Run 运行程序.bat to test

==================================================

TROUBLESHOOTING:

If program doesn't start:
- Make sure MSYS2 is installed at C:\msys64
- Try running: C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "./blackhole_demo.exe"

================================================== 