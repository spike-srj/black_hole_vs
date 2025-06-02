#version 330 core
layout (location = 0) in vec3 aPos;

out vec3 outUV;
out vec3 outFragPos;


uniform mat4 _modelMatrix;
uniform mat4 _viewMatrix;
uniform mat4 _projMatrix;

void main()
{
   vec4 _pos = _projMatrix * _viewMatrix * vec4(aPos.x, aPos.y, aPos.z, 1.0);
   outUV = aPos;
   gl_Position = _pos.xyww;
};