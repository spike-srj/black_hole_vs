#version 330 core
layout (location = 0) in vec3 aPos; // ���� NDC ����λ��

// ���ǲ���Ҫ��Ƭ����ɫ�������κζ�����Ϣ��
// ��Ϊ���м��㶼����Ƭ������� uniforms

void main()
{
    // ֱ�ӽ�����λ������Ϊ�ü��ռ�����
    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
}