#version 330 core
out vec4 FragColor;

in vec2 outUV;
in vec3 outFragPos;

uniform sampler2D  ourTexture;

void main()
{
    FragColor = texture(ourTexture , outUV);
};