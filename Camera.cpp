#include"Camera.h"


void Camera::lookAt(glm::vec3 _pos, glm::vec3 _front, glm::vec3 _up)
{
	m_position = _pos;
	m_front = glm::normalize(_front);
	m_up = _up;
	m_vMatrix = glm::lookAt(m_position, m_position + m_front, m_up);
}

void Camera::update()
{
	m_vMatrix = glm::lookAt(m_position, m_position + m_front, m_up);

}

glm::mat4 Camera::getMatrix()
{
	return m_vMatrix;
}


glm::vec3 Camera::getPosition()
{
	return m_position;
}

glm::vec3 Camera::getDirection()
{
	return m_front;
}





//����move����
void Camera::move(CAMERA_MOVE _mode)
{
	switch (_mode)
	{
	case CAMERA_MOVE::MOVE_LEFT:
		m_position -= glm::normalize(glm::cross(m_front, m_up)) * m_speed;
		break;
	case CAMERA_MOVE::MOVE_RIGHT:
		m_position += glm::normalize(glm::cross(m_front, m_up)) * m_speed;
		break;
	case CAMERA_MOVE::MOVE_FRONT:
		m_position += m_speed * m_front;
		break;
	case CAMERA_MOVE::MOVE_BACK:
		m_position -= m_speed * m_front;
		break;
	default:
		break;
	}
}
void Camera::pitch(float yOffset)
{
	m_pitch += yOffset * m_sensitivity;
	//��ס���÷���ͷ
	if (m_pitch >= 89.0f)
	{
		m_pitch = 89.0f;
	}
	if (m_pitch <= -89.0f)
	{
		m_pitch = -89.0f;
	}
	//����front����
	m_front.y = sin(glm::radians(m_pitch));
	m_front.x = cos(glm::radians(m_yaw)) * cos(glm::radians(m_pitch));
	m_front.z = sin(glm::radians(m_yaw)) * cos(glm::radians(m_pitch));
	m_front = glm::normalize(m_front);
	update();
}
void Camera::yaw(float xOffset)
{
	m_yaw += xOffset * m_sensitivity;
	if (m_pitch >= 89.0f)
	{
		m_pitch = 89.0f;
	}
	if (m_pitch <= -89.0f)
	{
		m_pitch = -89.0f;
	}
	//����front����
	m_front.y = sin(glm::radians(m_pitch));
	m_front.x = cos(glm::radians(m_yaw)) * cos(glm::radians(m_pitch));
	m_front.z = sin(glm::radians(m_yaw)) * cos(glm::radians(m_pitch));
	//��һ��
	m_front = glm::normalize(m_front);
	update();
}
void Camera::sensitivity(float _s)
{
	m_sensitivity = _s;
}

void Camera::onMouseMove(double _xpos, double _ypos)
{
	if (m_firstMove)
	{
		m_xpos = _xpos;
		m_ypos = _ypos;
		m_firstMove = false;
		return;
	}

	float _xOffset = _xpos - m_xpos;
	float _yOffset = -(_ypos - m_ypos);
	//��������
	m_xpos = _xpos;
	m_ypos = _ypos;

	pitch(_yOffset);
	yaw(_xOffset);

}