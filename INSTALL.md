# 安装指南

本文档将指导您如何设置开发环境并成功编译运行黑洞演示项目。

## 环境要求

- Windows 10/11
- 支持OpenGL 3.3+的显卡驱动

## 方法一：使用Visual Studio Code + CMake（推荐）

### 1. 安装必要软件

#### 1.1 安装Visual Studio Code
- 下载地址：https://code.visualstudio.com/
- 安装时选择"添加到PATH"选项

#### 1.2 安装CMake
- 下载地址：https://cmake.org/download/
- 选择"Windows x64 Installer"
- 安装时选择"Add CMake to the system PATH"

#### 1.3 安装编译器
选择以下任一选项：

**选项A：Visual Studio Build Tools（推荐）**
- 下载地址：https://visualstudio.microsoft.com/zh-hans/visual-cpp-build-tools/
- 安装时选择"C++ build tools"工作负载
- 包含MSVC v143编译器工具集

**选项B：MinGW-w64**
- 下载MSYS2：https://www.msys2.org/
- 安装后运行MSYS2，执行：
  ```bash
  pacman -S mingw-w64-x86_64-gcc
  pacman -S mingw-w64-x86_64-cmake
  ```
- 将`C:\msys64\mingw64\bin`添加到系统PATH

### 2. 安装依赖库

#### 2.1 安装vcpkg（包管理器）
```powershell
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
```

#### 2.2 安装GLFW
```powershell
.\vcpkg install glfw3:x64-windows
```

### 3. 配置VS Code

#### 3.1 安装扩展
- C/C++ Extension Pack
- CMake Tools

#### 3.2 配置项目
1. 在VS Code中打开项目文件夹
2. 按`Ctrl+Shift+P`，选择"CMake: Configure"
3. 选择编译器工具链
4. CMake会自动配置项目

### 4. 构建和运行
1. 按`Ctrl+Shift+P`，选择"CMake: Build"
2. 构建成功后，可执行文件位于`build/bin/`目录
3. 运行：`./build/bin/blackhole_demo.exe`

## 方法二：使用命令行构建

### 1. 安装依赖
按照方法一的步骤1-2安装CMake、编译器和vcpkg

### 2. 命令行构建
```powershell
# 创建构建目录
mkdir build
cd build

# 配置项目（使用vcpkg）
cmake -DCMAKE_TOOLCHAIN_FILE=[vcpkg安装路径]/scripts/buildsystems/vcpkg.cmake ..

# 构建项目
cmake --build . --config Release

# 运行
.\bin\blackhole_demo.exe
```

## 方法三：手动下载GLFW库

如果无法使用vcpkg，可以手动下载GLFW：

### 1. 下载GLFW
- 访问：https://www.glfw.org/download.html
- 下载"64-bit Windows binaries"
- 解压到项目根目录的`third_party/glfw/`

### 2. 目录结构
确保目录结构如下：
```
third_party/glfw/
├── include/
│   └── GLFW/
│       └── glfw3.h
└── lib-vc2022/  # 或 lib-mingw-w64/
    └── glfw3.lib
```

### 3. 构建
```powershell
mkdir build
cd build
cmake ..
cmake --build . --config Release
```

## 故障排除

### 问题1：找不到CMake
**解决方案：**
- 确保CMake已正确安装
- 重启命令行窗口
- 检查系统PATH环境变量

### 问题2：找不到编译器
**解决方案：**
- 确保已安装Visual Studio Build Tools或MinGW
- 对于MinGW，确保`mingw64\bin`在PATH中
- 重启命令行窗口

### 问题3：找不到GLFW
**解决方案：**
- 确保vcpkg已正确安装GLFW
- 检查CMake配置是否使用了正确的toolchain文件
- 尝试手动下载GLFW库

### 问题4：OpenGL错误
**解决方案：**
- 更新显卡驱动
- 确保显卡支持OpenGL 3.3+
- 检查shader和res目录是否存在

### 问题5：运行时找不到DLL
**解决方案：**
- 确保GLFW的DLL文件在可执行文件目录或PATH中
- 对于vcpkg构建，DLL通常会自动复制

## 项目文件说明

- `CMakeLists.txt` - CMake配置文件
- `quick_build.bat` - 快速构建脚本（需要MinGW）
- `Makefile` - Make构建文件
- `setup.bat` - 自动安装脚本

## 运行检查清单

运行前确保：
- [x] 编译成功，生成了blackhole_demo.exe
- [x] shader/目录存在且包含.glsl文件
- [x] res/目录存在且包含纹理文件
- [x] 显卡驱动已更新

## 获取帮助

如果遇到问题：
1. 检查所有依赖是否正确安装
2. 查看CMake或编译器的错误信息
3. 确保使用支持的编译器版本
4. 检查项目完整性 