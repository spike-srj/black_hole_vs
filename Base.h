#pragma once
#include <glad/glad.h> 
#include <GLFW/glfw3.h>
#include <iostream>
#include<string>
#include<fstream>
#include<sstream>
//glm��һ����ѧ��   
#include"glm/glm.hpp"
#include"glm/gtc/matrix_transform.hpp"
#include"glm/gtc/type_ptr.hpp"

//��������Լ�ϰ�ߵ��������͡�
//����1��Ϊ����Ӧ��ͬƽ̨�ľ��ȣ�ֻҪ�������double��float����
typedef unsigned int	uint;
typedef unsigned char	byte;

//�洢rgba��ͼƬ���ݽṹ
struct ffRGBA
{
	byte m_r;
	byte m_g;
	byte m_b;
	byte m_a;

	ffRGBA(byte _r = 255,
		byte _g = 255,
		byte _b = 255,
		byte _a = 255)
	{
		m_r = _r;
		m_g = _g;
		m_b = _b;
		m_a = _a;
	}
};

//��ά����ģ�壨�����������position��TΪfloat�ࣩ
template<typename T>
struct tVec3
{
	T	m_x;
	T	m_y;
	T	m_z;
	tVec3(T _x = 0, T _y = 0, T _z = 0)
	{
		m_x = _x;
		m_y = _y;
		m_z = _z;
	}
};

//��ά����ģ��
template<typename T>
struct tVec2
{
	T	m_x;
	T	m_y;

	tVec2(T _x = 0, T _y = 0)
	{
		m_x = _x;
		m_y = _y;
	}
};