# 黑洞演示项目

一个使用OpenGL和GLFW实现的黑洞引力透镜效果演示项目。

## 功能特性

- 实时黑洞引力透镜效果渲染
- 自由摄像机控制
- 天空盒环境映射
- 实时FPS显示

## 系统要求

- Windows 10/11 或 Linux/macOS
- 支持OpenGL 3.3+的显卡
- CMake 3.16+
- C++17兼容的编译器 (MSVC 2019+, GCC 8+, Clang 8+)

## 依赖库

- **GLFW** - 窗口管理和输入处理
- **GLAD** - OpenGL加载器 (已包含在项目中)
- **GLM** - 数学库 (已包含在项目中)
- **STB Image** - 图像加载 (已包含在项目中)

## 构建方法

### 方法一：使用vcpkg（推荐）

1. 安装vcpkg：
```bash
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.bat  # Windows
# 或者
./bootstrap-vcpkg.sh   # Linux/macOS
```

2. 安装GLFW：
```bash
./vcpkg install glfw3:x64-windows  # Windows
# 或者
./vcpkg install glfw3              # Linux/macOS
```

3. 构建项目：
```bash
mkdir build
cd build
cmake -DCMAKE_TOOLCHAIN_FILE=[vcpkg根目录]/scripts/buildsystems/vcpkg.cmake ..
cmake --build .
```

### 方法二：手动提供GLFW库

1. 下载GLFW预编译库
2. 在项目根目录创建 `third_party/glfw/` 目录
3. 将GLFW的include和lib文件放入相应目录：
   ```
   third_party/glfw/
   ├── include/
   │   └── GLFW/
   └── lib/
       └── glfw3.lib  # Windows
   ```

4. 构建：
```bash
mkdir build
cd build
cmake ..
cmake --build .
```

### 方法三：系统包管理器（Linux）

```bash
# Ubuntu/Debian
sudo apt install libglfw3-dev

# Fedora
sudo dnf install glfw-devel

# 然后构建
mkdir build
cd build
cmake ..
make
```

## 运行

构建成功后，可执行文件位于 `build/bin/` 目录下：

```bash
cd build/bin
./blackhole_demo.exe  # Windows
# 或者
./blackhole_demo      # Linux/macOS
```

## 控制方法

- **W/A/S/D** - 摄像机移动
- **鼠标** - 摄像机旋转
- **ESC** - 退出程序

## 项目结构

```
├── main_bh.cpp          # 主程序
├── Shader.cpp/h         # 着色器管理
├── Camera.cpp/h         # 摄像机控制
├── ffimage.cpp/h        # 图像加载
├── Base.h               # 基础定义
├── shader/              # GLSL着色器文件
├── res/                 # 纹理资源
├── glm/                 # GLM数学库
└── CMakeLists.txt       # CMake配置
```

## 故障排除

### 找不到GLFW库
- 确保已正确安装GLFW库
- 检查CMake输出的警告信息
- 尝试使用vcpkg安装GLFW

### 编译错误
- 确保使用支持C++17的编译器
- 检查OpenGL驱动是否已更新

### 运行时黑屏
- 确保显卡支持OpenGL 3.3+
- 检查shader目录和res目录是否正确复制到输出目录

## 开发环境

推荐使用以下IDE进行开发：
- Visual Studio Code + CMake插件
- CLion
- Visual Studio 2019/2022
- Qt Creator

## 许可证

本项目仅供学习和演示使用。 