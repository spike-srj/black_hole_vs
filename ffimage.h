#pragma once
#include"Base.h"
//ͼƬ�࣬����ʹ��ʱֱ��ʵ����
class ffImage
{
private:
	int					m_width;
	int					m_height;
	int					m_picType;//ͼƬ����
	ffRGBA*				m_data;//ͼƬ���ݣ���һ��rgba������
public:
	//���õ�get�ӿ�
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
	//���캯��
	ffImage(int _width = 0, int _height = 0, int _picType = 0, ffRGBA* _data = NULL)
	{
		//��ֵ
		m_width = _width;
		m_height = _height;
		m_picType = _picType;
		//��������ͼ���׷�����ٸ�rgba�ռ�
		int _sumSize = m_width * m_height;
		if (_data && _sumSize)
		{
			//���ݲ�Ϊ�գ�Ϊdata����ռ䣬rgba����
			m_data = new ffRGBA[_sumSize];
			//����������_data���鿽����m_data
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
	//��ȡ·���µ�ͼƬ����������ffimage���͵Ķ����ٰ������أ�����Ҫ�����κε�һ�����еĲ���
	static ffImage* readFromFile(const char* _fileName);
};

