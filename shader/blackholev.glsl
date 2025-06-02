#version 330 core
layout (location = 0) in vec3 aPos; // 接收 NDC 顶点位置

// 我们不需要向片段着色器传递任何额外信息，
// 因为所有计算都基于片段坐标和 uniforms

void main()
{
    // 直接将顶点位置设置为裁剪空间坐标
    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
}