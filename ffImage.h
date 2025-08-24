#pragma once
#include"Base.h"
//图片类，方便使用时直接实例化
class ffImage
{
private:
	int					m_width;
	int					m_height;
	int					m_picType;//图片类型
	ffRGBA*				m_data;//图片数据，是一个rgba的数组
public:
	//常用的get接口
	int			getWidth()const { return m_width; }
	int			getHeight()const { return m_height; }
	int			getPicType()const { return m_picType; }
	ffRGBA*		getData()const { return m_data; }

	ffRGBA getColor(int x, int y)const
	{
		if (x < 0 || x > m_width - 1 || y <0 || y > m_height - 1)
		{
			return ffRGBA(0, 0, 0, 0);
		}
		return m_data[y * m_width + x];
	}
	//构造函数
	ffImage(int _width = 0, int _height = 0, int _picType = 0, ffRGBA* _data = NULL)
	{
		//赋值
		m_width = _width;
		m_height = _height;
		m_picType = _picType;
		//计算这张图到底分配多少个rgba空间
		int _sumSize = m_width * m_height;
		if (_data && _sumSize)
		{
			//数据不为空，为data分配空间，rgba类型
			m_data = new ffRGBA[_sumSize];
			//将传进来的_data数组拷贝进m_data
			memcpy(m_data, _data, sizeof(ffRGBA) * _sumSize);
		}
		else
		{
			m_data = NULL;
		}
	}
	~ffImage()
	{
		if (m_data)
		{
			delete[]m_data;
		}
	}

public:
	//读取路径下的图片并解析构成ffimage类型的对象再把它返回，不需要调用任何单一对象中的参数
	static ffImage* readFromFile(const char* _fileName);
};

