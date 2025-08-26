# Black Hole Gravitational Lensing Demo (OpenGL/GLSL)

A real‑time demo that renders gravitational lensing and the shadow of a black hole using OpenGL and GLSL. The fragment shader integrates photon null geodesics in a Schwarzschild spacetime (2D orbital‑plane reduction) and samples a skybox for the background.

---

## Features
- Real‑time black hole shadow and lensing (Schwarzschild; 2D orbital‑plane integration).
- Skybox background environment to visualize strong lensing.
- Basic camera controls: W/A/S/D to move, mouse to look, ESC to quit.
- FPS printed to console once per second.

---

## Directory Layout
```
blackhole_demo_vs/
├─ src/               # C++ sources (main_bh.cpp, Shader.cpp, Camera.cpp, ffimage.cpp, glad_loader.c)
├─ include/           # Headers (Base.h, Shader.h, Camera.h, ffImage.h, stb_image.h)
├─ external/          # Third‑party headers (glad/, glm/)
├─ shader/            # GLSL shaders (blackholev.glsl, blackholef.glsl, sky* shaders, experiments/)
├─ res/               # Assets (skybox, textures)
├─ bin/               # Runtime output (exe, DLLs, copied shader/ & res/)
├─ build/             # CMake/Make build directory
├─ docs/              # Documentation
├─ scripts/           # Utility scripts
├─ CMakeLists.txt
├─ Makefile
└─ build.bat          # MSYS2/MinGW one‑shot build script (Windows)
```

---

## Build
You can build with Visual Studio (MSVC) or MSYS2/MinGW. A convenience `build.bat` is also provided.

### Option A: CMake + Visual Studio (MSVC)
```powershell
cmake -S . -B build
cmake --build build --config Release -j
# Run
./build/bin/blackhole_demo.exe
```
Notes:
- CMake POST_BUILD commands copy `shader/` and `res/` into `build/bin/`.
- If GLFW is not found, put a prebuilt copy under `third_party/glfw/{include,lib}` or install via vcpkg.

### Option B: CMake + MinGW (MSYS2)
```bash
cmake -S . -B build -G "MinGW Makefiles"
cmake --build build -j
# Run
cd build/bin && ./blackhole_demo.exe
```
GLFW:
- Recommended: `pacman -S mingw-w64-x86_64-glfw`
- Or provide `third_party/glfw/{include,lib}` (CMake prefers that if present).

### Option C: Makefile (MSYS2 MinGW64)
```bash
make
cd bin && ./blackhole_demo.exe
```
If runtime DLLs are missing, copy `glfw3.dll` and MinGW runtime (`libgcc_s_seh-1.dll`, `libstdc++-6.dll`, `libwinpthread-1.dll`) into `bin/`.

### Option D: Windows Script (build.bat)
```powershell
./build.bat
```
This script invokes the MSYS2 MinGW64 toolchain and syncs `shader/` and `res/` to `bin/` pre/post build.

---

## Run & Controls
- Run from `bin/blackhole_demo.exe` (or `build/bin/blackhole_demo.exe`).
- Controls:
  - ESC: quit
  - W/A/S/D: move camera
  - Mouse: look (cursor is disabled and captured)
- Console shows FPS once per second.

---

## Shaders & Algorithm
Core shaders:
- `shader/blackholev.glsl` (vertex): draws a fullscreen triangle.
- `shader/blackholef.glsl` (fragment): performs geodesic ray‑marching and skybox sampling.

Key uniforms in the fragment shader:
- `iResolution (vec3)`: viewport size in pixels
- `iTime (float)`: time in seconds
- `invViewMatrix (mat4)`: inverse view matrix to build world‑space rays
- `SchwarzschildRadius (float)`: BH radius (code uses default `1.0`)
- `blackholeCenterWorld (vec3)`: BH center in world coordinates
- `skyboxSampler (samplerCube)`: skybox cubemap

High‑level algorithm:
1. Map pixel coordinates to a view‑space direction, transform to world space using `invViewMatrix`.
2. Build the orbital plane from the relative position to the BH and the initial ray direction; estimate angular momentum magnitude `L`.
3. Integrate null geodesic ODEs in Schwarzschild using adaptive stepping (RK4) on `(r, φ)` with turning‑point handling and horizon capture.
4. If captured (inside the horizon while inward), output black; otherwise convert the final tangent to a world direction and sample the skybox.

Implementation notes:
- The shader uses a "sparse angle wrap": `φ` is only wrapped when `|φ|` exceeds a threshold to avoid per‑step modulo cost.
- Constants controlling stepping and stability (see `blackholef.glsl`):
  - `MAX_STEPS`, `MAX_TRACE_R`, `EPSILON`, `HORIZON_TOL`
  - `MAX_REFINES` (backtracking), `FLIP_HYST_FRAC` (turning‑point hysteresis)
  - `D_LAMBDA_MIN`, `D_LAMBDA_MAX`, `MAX_DR_FRACTION`, `MAX_DPHI`
  - `PHI_SPARSE_WRAP_THRESHOLD` (angle wrap threshold)

For a deeper derivation and practical guidance, see `docs/blackhole_ray_stepping_zh.md` (Chinese).

---

## Key Code Structure
- `src/main_bh.cpp`: window/context, camera update, uniforms, fullscreen draw.
- `src/Shader.cpp`: shader compilation/linking and uniform helpers.
- `src/Camera.cpp`: FPS camera (WASD + mouse look).
- `src/ffimage.cpp`: texture loading (stb_image).
- `src/glad_loader.c`: OpenGL function loader (GLAD).

---

## Dependencies
- OpenGL 3.3+
- GLFW 3.3+
- GLM (header‑only)
- GLAD (included)
- stb_image (included)

CMake tries to find system OpenGL/GLFW; on Windows it will use `third_party/glfw` if provided.

---

## Performance Tips
- Increase `D_LAMBDA_MAX` and relax `MAX_DPHI` in far field; keep tighter values near the photon sphere/horizon.
- Reduce `MAX_REFINES` if backtracking triggers often; prefer predicting turning points by compressing step size when `dr^2` is small.
- Consider a weak‑field analytic deflection for very large impact parameters to skip integration.
- For large scenes, render outside a BH‑influence radius with a cheaper path or lower resolution, then upsample with TAA.

---

## Troubleshooting
- Missing `glfw3.dll` (Windows): copy `glfw3.dll` and MinGW runtime DLLs into `bin/`, or install GLFW via vcpkg/VS so it’s on PATH.
- Black screen: ensure `bin/shader/` and `bin/res/` exist and contain assets; check console for shader compile errors.
- Garbled Chinese comments: sources are UTF‑8 (with BOM). With MSVC, add `/utf-8` to compiler options.

---

## License
MIT License (see LICENSE if present in the repo root).

---

## Credits
- GLFW, GLM, GLAD, stb_image
- Community implementations and literature on black hole ray tracing
