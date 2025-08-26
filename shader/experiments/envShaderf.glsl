#version 330 core
out vec4 FragColor;

in vec3 outNormal;
in vec3 outPos;

uniform vec3 _viewPos;
uniform samplerCube  ourTexture;

void main()
{
    vec3 I = normalize(outPos - _viewPos);
    vec3 R = reflect(I, normalize(outNormal));
    FragColor = texture(ourTexture , R);
};