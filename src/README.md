This folder is reserved for core source files.

Current build still references sources at the repository root to avoid
encoding issues when moving files. In a follow-up step, migrate:
- Shader.cpp, Camera.cpp, ffimage.cpp -> src/
- main_bh.cpp -> src/main.cpp (or keep as app entry)

Then update CMake sources to point to src/ paths only.

