# 黑洞引力透镜演示 / Black Hole Gravitational Lensing Demo

本项目是一个使用 OpenGL/GLSL 实时渲染黑洞引力透镜效果的示例程序，核心通过片元着色器在 Schwarzschild 时空中对光线（零测地线）进行数值步进；背景来自天空盒贴图。/ A real‑time OpenGL/GLSL demo that renders black hole gravitational lensing. The core integrates null geodesics in a Schwarzschild spacetime inside the fragment shader; the background is sampled from a skybox.

---

## 功能概览 / Features
- 实时黑洞引力透镜与阴影（Schwarzschild 模型，轨道面 2D 约化）。
- 天空盒环境贴图采样，展示强透镜扭曲。 
- 基本相机控制：W/A/S/D 平移，鼠标转向，ESC 退出。
- 控制台输出 FPS（每秒刷新一次）。

- Real‑time BH lensing and shadow (Schwarzschild model, 2D orbital-plane reduction).
- Skybox environment sampling to visualize strong lensing.
- Basic camera controls: W/A/S/D translation, mouse look, ESC to quit.
- FPS printed to console (refreshed every second).

---

## 目录结构 / Directory Layout
```
blackhole_demo_vs/
├─ src/               # C++ sources (main_bh.cpp, Shader.cpp, Camera.cpp, ffimage.cpp, glad_loader.c)
├─ include/           # Headers (Base.h, Shader.h, Camera.h, ffImage.h, stb_image.h)
├─ external/          # Third‑party headers (glad/, glm/)
├─ shader/            # GLSL shaders (blackholev.glsl, blackholef.glsl, sky* shaders, experiments/)
├─ res/               # Assets (skybox, textures)
├─ bin/               # Runtime output (blackhole_demo.exe, dlls, copied shader/ & res/)
├─ build/             # CMake/Make build directory
├─ docs/              # Documentation
├─ scripts/           # Utility scripts
├─ CMakeLists.txt
├─ Makefile
└─ build.bat          # MSYS2/MinGW one‑shot build script (Windows)
```

---

## 构建 / Build
项目支持 Visual Studio (MSVC) 与 MinGW（MSYS2）；也可使用随附的 build.bat。/ Build with Visual Studio (MSVC) or MinGW (MSYS2); a convenience build.bat is provided.

### 方式 A：CMake + Visual Studio (MSVC) / CMake + MSVC
```powershell
cmake -S . -B build
cmake --build build --config Release -j
# 运行 / Run
./build/bin/blackhole_demo.exe
```
说明：CMake 已在 POST_BUILD 阶段将 shader/ 与 res/ 复制到 build/bin/。/ Shaders and assets are copied into build/bin/ via POST_BUILD.

### 方式 B：CMake + MinGW (MSYS2)
```bash
cmake -S . -B build -G "MinGW Makefiles"
cmake --build build -j
# 运行 / Run
cd build/bin && ./blackhole_demo.exe
```
GLFW 获取方式：
- pacman 安装（推荐）：`pacman -S mingw-w64-x86_64-glfw`
- 或将预编译的 GLFW 放到 `third_party/glfw/{include,lib}`（CMake 会尝试优先使用）。

### 方式 C：Makefile（MSYS2 MinGW64） / Makefile
```bash
make
cd bin && ./blackhole_demo.exe
```
若缺少运行时 DLL，请将 `glfw3.dll` 及 MinGW 运行时 `libgcc_s_seh-1.dll`、`libstdc++-6.dll`、`libwinpthread-1.dll` 复制到 `bin/`。/ If runtime DLLs are missing, copy them into `bin/`.

### 方式 D：Windows 脚本 / build.bat
```powershell
./build.bat
```
该脚本会调用 MSYS2 MinGW64 工具链编译，并在构建前后同步 `shader/` 与 `res/` 到 `bin/`。/ The script builds via MSYS2 MinGW64 and syncs shader/ and res/ into bin/ pre/post build.

---

## 运行 & 控制 / Run & Controls
- 运行：`bin/blackhole_demo.exe`（或 `build/bin/blackhole_demo.exe`）。/ Run the executable from bin/ or build/bin/.
- 控制 / Controls：
  - ESC：退出 / Quit
  - W/A/S/D：相机平移 / Move camera
  - 鼠标：视角转动（程序会隐藏并捕获鼠标）/ Mouse look (cursor disabled & captured)
- 控制台：每秒打印一次 FPS。/ FPS is printed once per second.

---

## 着色器与算法 / Shaders & Algorithm
核心着色器：`shader/blackholef.glsl`（片元）与 `shader/blackholev.glsl`（顶点，绘制全屏三角形）。/ Core shaders: fragment `blackholef.glsl` and vertex `blackholev.glsl` (fullscreen triangle).

片元着色器关键 Uniforms / Key uniforms:
- `iResolution(vec3)`: 视口像素尺寸 / viewport size
- `iTime(float)`: 运行时间 / time in seconds
- `invViewMatrix(mat4)`: 相机视图矩阵的逆，用于将像素射线变到世界空间 / inverse view matrix to build world‑space rays
- `SchwarzschildRadius(float)`: Schwarzschild 半径（代码默认 1.0）/ BH radius (default 1.0)
- `blackholeCenterWorld(vec3)`: 黑洞世界坐标中心 / BH center in world space
- `skyboxSampler(samplerCube)`: 天空盒 / skybox cubemap

算法摘要 / Algorithm summary：
- 将屏幕像素方向（相机系）变换到世界空间，计算相对黑洞的初始位置向量与角动量，确定轨道面基向量；/ Map pixel ray to world space, compute relative position and angular momentum, build orbital plane.
- 在 Schwarzschild 时空的 2D 轨道面上，数值积分零测地线的一阶方程（`dr/dλ`、`dφ/dλ`），自适应步长并在转向点翻转径向符号；/ Integrate null geodesics in the 2D orbital plane with adaptive stepping and turning‑point handling.
- 落入视界则输出黑色；逃逸则依据末端速度方向采样天空盒，实现透镜效果。/ Rays captured by the horizon are black; escaping rays sample the skybox using the final direction.
- 为性能与稳定性实现了“稀疏角度归一化”：仅当 `|φ|` 超阈值（默认 300rad）才做一次 `wrap_angle`。/ Sparse angle wrapping is used: wrap only if `|φ|` exceeds a threshold (default 300 rad).

更多细节请见 `docs/blackhole_ray_stepping_zh.md`。/ See `docs/blackhole_ray_stepping_zh.md` for in‑depth details.

---

## 关键代码结构 / Key Code Structure
- `src/main_bh.cpp`：窗口上下文、相机更新、uniforms 设置、全屏绘制。/ Window/context, camera update, uniforms, fullscreen draw.
- `src/Shader.cpp`：着色器加载/编译/链接与 uniform 设置。/ Shader program utils.
- `src/Camera.cpp`：简单相机，WASD + Mouse。/ Simple camera movement and mouse look.
- `src/ffimage.cpp`：纹理加载（基于 stb_image）。/ Texture loading (stb_image).
- `src/glad_loader.c`：OpenGL 函数加载。/ GLAD loader.

---

## 依赖 / Dependencies
- OpenGL 3.3+
- GLFW 3.3+
- GLM (header‑only)
- GLAD (included)
- stb_image (included)

若使用 CMake，工程会尝试自动查找系统 OpenGL 与 GLFW；Windows 下也可使用 `third_party/glfw`（如存在）中的预编译库。/ CMake will find system OpenGL/GLFW; on Windows, prebuilt GLFW in `third_party/glfw` is used if present.

---

## 常见问题 / Troubleshooting
- 运行时报缺少 `glfw3.dll` / Missing `glfw3.dll`:
  - 将 `glfw3.dll` 与 MinGW 运行时 DLL 复制到 `bin/`；或使用 VS/VC‑pkg 安装 GLFW 并在 PATH 中可见。/ Copy DLLs into `bin/` or install GLFW via vcpkg/VS so it’s on PATH.
- 程序黑屏 / Black screen:
  - 确认 `bin/shader/` 与 `bin/res/` 存在且包含资源；检查控制台错误输出。/ Ensure `bin/shader/` and `bin/res/` exist; check console.
- 编码导致的中文显示问题 / Garbled Chinese text:
  - 源码采用 UTF‑8（带 BOM）；建议编译器参数使用 `/utf-8`（MSVC）。/ Sources are UTF‑8 (BOM). Use `/utf-8` with MSVC.

---

## 许可 / License
MIT License（若仓库根目录提供 LICENSE 文件，则以该文件为准）。/ MIT License (subject to LICENSE in repo root).

---

## 鸣谢 / Credits
- GLFW, GLM, GLAD, stb_image
- 以及社区关于黑洞光线追踪的开源实现与论文参考。/ And community implementations and literature on BH ray tracing.