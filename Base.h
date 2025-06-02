#pragma once
#include <glad/glad.h> 
#include <GLFW/glfw3.h>
#include <iostream>
#include<string>
#include<fstream>
#include<sstream>
//glm是一个数学包   
#include"glm/glm.hpp"
#include"glm/gtc/matrix_transform.hpp"
#include"glm/gtc/type_ptr.hpp"

//定义符合自己习惯的数据类型。
//作用1：为了适应不同平台的精度，只要在这里改double和float就行
typedef unsigned int	uint;
typedef unsigned char	byte;

//存储rgba的图片数据结构
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

//三维向量模板（如果用来描述position则T为float类）
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

//二维向量模板
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