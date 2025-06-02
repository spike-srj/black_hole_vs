#version 330 core
out vec4 FragColor;

in vec3 outUV;
in vec3 outFragPos;

uniform samplerCube  ourTexture;

void main()
{
    FragColor = texture(ourTexture , outUV);
};