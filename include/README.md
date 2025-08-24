Public headers live here. Once sources are migrated to src/, move headers:
- Base.h, Shader.h, Camera.h, ffImage.h, stb_image.h

Note: Some source files include headers with different case (e.g., Shader.h vs shader.h).
Keep a single canonical header name and, if needed, add a thin alias wrapper
to maintain compatibility across platforms.

