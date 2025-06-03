# 黑洞引力透镜效应演示程序

🌌 **一个实时的黑洞引力透镜效果OpenGL演示程序**

## ✅ 项目状态：已成功编译并运行！

该项目已成功从Visual Studio专用项目转换为跨平台项目，可以在任何支持MinGW的环境中编译和运行。

## 🎯 功能特性

- **实时黑洞引力透镜渲染**: 使用GPU着色器模拟光线在黑洞附近的弯曲
- **动态相机系统**: 相机自动在黑洞周围运动，展示不同角度的视觉效果
- **物理精确计算**: 基于史瓦西半径(Rs)的距离计算和引力效应
- **性能监控**: 实时FPS显示和调试信息输出
- **高质量天空盒**: 使用6面立方体贴图营造宇宙环境

## 🚀 快速运行

### 方法1：使用启动脚本
```bash
run_blackhole_demo.bat
```

### 方法2：直接运行
```bash
blackhole_demo.exe
```

## 🔧 从源码编译

### 环境要求
- Windows 10/11
- MSYS2 + MinGW-w64
- GLFW 3.4+
- OpenGL 3.3+

### 编译步骤
```bash
# 使用MSYS2环境
C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64

# 编译各个源文件
g++ -std=c++17 -I. -Iglm ffimage.cpp -c -o ffimage.o
g++ -std=c++17 -I. -Iglm Camera.cpp -c -o Camera.o  
g++ -std=c++17 -I. -Iglm Shader.cpp -c -o Shader.o
g++ -std=c++17 -I. -Iglm main_bh.cpp -c -o main_bh.o
gcc -c glad_loader.c -o glad_loader.o -I.

# 链接生成可执行文件
g++ ffimage.o Camera.o Shader.o main_bh.o glad_loader.o -o blackhole_demo.exe -lglfw3 -lopengl32 -lgdi32 -luser32 -lshell32
```

启动命令：C:\msys64\msys2_shell.cmd -defterm -here -no-start -mingw64 -c "./blackhole_demo.exe"
## 📁 项目结构

```
blackhole_demo_vs/
├── blackhole_demo.exe         # 🎯 可执行文件 (544KB)
├── run_blackhole_demo.bat     # 🚀 启动脚本
├── glad_loader.c              # 自定义OpenGL函数加载器
├── glad/glad.h                # 简化的OpenGL头文件
├── shader/                    # 着色器文件目录
│   ├── blackholev.glsl        # 顶点着色器
│   ├── blackholef.glsl        # 片段着色器（主要效果）
│   ├── skyShaderv.glsl        # 天空盒顶点着色器
│   └── skyShaderf.glsl        # 天空盒片段着色器
├── res/                       # 资源文件目录
│   └── skybox3/              # 天空盒纹理
│       ├── front.jpg         # 前面
│       ├── back.jpg          # 后面
│       ├── left.jpg          # 左面
│       ├── right.jpg         # 右面
│       ├── top.jpg           # 上面
│       └── bottom.jpg        # 下面
├── glm/                      # GLM数学库
├── Camera.cpp/.h             # 相机系统
├── Shader.cpp/.h             # 着色器管理
├── ffimage.cpp/.h            # 图像加载
├── main_bh.cpp               # 主程序文件
└── 构建相关文件...
```

## 🎮 程序控制

- **ESC键**: 退出程序
- **鼠标**: 可能支持相机控制（需要测试）
- **WASD键**: 可能支持相机移动（需要测试）

## 📊 运行时信息

程序运行时会在控制台输出以下信息：
```
--- Frame 30 ---
Distance to BH: 10.00 Rs (based on simulation units)
Camera Pos: (0.00, 0.00, 10.00)
FPS: 11.74
```

- **Frame**: 当前帧数
- **Distance to BH**: 到黑洞的距离（以史瓦西半径Rs为单位）
- **Camera Pos**: 相机在3D空间中的位置
- **FPS**: 每秒帧数

## 🛠️ 技术细节

### 核心技术
- **OpenGL 3.3**: 现代OpenGL管线
- **GLSL着色器**: GPU计算引力透镜效果
- **GLM数学库**: 矩阵和向量运算
- **GLFW**: 窗口管理和输入处理
- **STB_Image**: 图像加载

### 物理模拟
- 基于广义相对论的光线弯曲计算
- 史瓦西黑洞度规
- 实时光线追踪效果

## 🎨 视觉效果

该程序展示了以下黑洞引力透镜效应：
- **引力红移**: 光线频率变化
- **光线弯曲**: 背景星空的扭曲
- **爱因斯坦环**: 在特定角度观察时的光环效果
- **时空扭曲**: 接近事件视界时的极端变形

## 📝 开发历程

这个项目经历了从Visual Studio专用到跨平台的完整转换：

1. ✅ 移除所有VS依赖（.sln, .vcxproj等）
2. ✅ 创建跨平台构建系统（CMake, Makefile）  
3. ✅ 解决OpenGL函数加载问题（自定义glad_loader）
4. ✅ 配置开发环境（VS Code, Git）
5. ✅ 成功编译并运行

## 🤝 贡献

欢迎提交issue和pull request来改进这个项目！

## 📄 许可证

本项目遵循MIT许可证。 