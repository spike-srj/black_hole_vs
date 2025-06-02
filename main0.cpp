#include"Base.h"
#include"Shader.h"
#include"ffImage.h"
#include"Camera.h"
#include <vector>
#include <map>
#include <GL/glut.h>
using namespace std;
//���ʹ�����ͼ


//
//���û��ı䴰�ڵĴ�С��ʱ���ӿ�ҲӦ�ñ�������
//�Դ���ע��һ���ص�����(Callback Function)��������ÿ�δ��ڴ�С��������ʱ�򱻵���
void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
	//glViewport����ǰ�����������ƴ������½ǵ�λ�á��������͵��ĸ�����������Ⱦ���ڵĿ�Ⱥ͸߶ȣ����أ�
	glViewport(0, 0, width, height);
}


/*******************************************���峣��************************************************/
//���ô��ڵĿ�͸�
const unsigned int WIDTH = 800;
const unsigned int HEIGHT = 600;
int _width = WIDTH;
int _height = HEIGHT;

uint VAO_cube = 0;
uint VAO_sky = 0; 
uint VAO_fullscreen_quad = 0; // ���ڴ����ڶ�Ƭ����ɫ��
//uint VAO_plane = 0;
//uint VAO_window = 0;
//uint VAO_screen = 0;
uint VAO_R_cube = 0;

ffImage* _pImage = NULL;

//����shader
Shader  _shader;
Shader  _shader_sky;
Shader  _shader_env;
Shader  _shader_blackhole;

//������ͼ
uint            _textureBox = 0;
uint            _textureSky = 0;
uint            _textureMilkway = 0;


Camera  _camera;
//glm::mat4 _viewMatrix(1.0f);
glm::mat4 _projMatrix(1.0f);



//��Ӧ���������¼�
//ESC�Ƴ�����
void processInput(GLFWwindow* window)
{
	if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
	{
		glfwSetWindowShouldClose(window, true);
	}
	if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
	{
		_camera.move(CAMERA_MOVE::MOVE_FRONT);
	}
	if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
	{
		_camera.move(CAMERA_MOVE::MOVE_BACK);
	}
	if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
	{
		_camera.move(CAMERA_MOVE::MOVE_LEFT);
	}
	if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
	{
		_camera.move(CAMERA_MOVE::MOVE_RIGHT);
	}
}
//�趨����ƶ��¼�, ÿ�μ�¼��һ��xy��λ�ã��Աȼ���pitch������
void mouse_callback(GLFWwindow* window, double xpos, double ypos)
{
	_camera.onMouseMove(xpos, ypos);
}

void rend()
{
	////����
	//std::vector<glm::vec3> _window_pos
	//{
	//	glm::vec3(-1.5f, 0.0f, -0.48f),
	//	glm::vec3(1.5f, 0.0f, 0.51f),
	//	glm::vec3(0.0f, 0.0f, 0.7f),
	//	glm::vec3(-0.3f, 0.0f, -2.3f),
	//	glm::vec3(0.5f, 0.0f, -0.6f)
	//};

	////�����������������Խ���Ĵ���Խ�����
	//std::map<float, glm::vec3> _window_sort;
	//for (int i = 0; i < _window_pos.size(); i++)
	//{
	//	float _dist = glm::length(_camera.getPosition() - _window_pos[i]);
	//	_window_sort[_dist] = _window_pos[i];
	//}

	//���������ɫ
	glClearColor(1.f, 0.3f, 0.3f, 1.0f);
	//�����ǰ���ڣ�����ɫ����Ϊ�����ɫ,�����Ȼ���
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	//����ȼ��Ȩ�ޣ���һ��Ӧ����clearǰ�棬��Ȩ�޲���clear
	// ��Ȳ��Կ��Խ��ã���Ϊ����ֻ��һ��ȫ��Ч�������߱����Ա�����ʹ��
	//glEnable(GL_DEPTH_TEST);
	////��blend���Ȩ��
	//glEnable(GL_BLEND);
	////���û�Ϸ�ʽ
	//glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);



	//����1���۾���λ��    2�������ĸ�����    3���Դ����Ϸ���ʲô����
	//_viewMatrix = glm::lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.update();
	glm::mat4 viewMatrix = _camera.getMatrix();
	glm::mat4 invViewMatrix = glm::inverse(viewMatrix);
	////����1���ӳ��Ƕ�fov 2����߱�    3����ƽ��   4��Զƽ��
	//_projMatrix = glm::perspective(glm::radians(45.0f), (float)_width / (float)_height, 0.1f, 100.0f);
	//glm::mat4 _modelMatrix(1.0f);
	////����1�����ĸ��������translate   2������ʲôtranslate 
	//_modelMatrix = glm::translate(_modelMatrix, glm::vec3(0.0f, 0.0f, -3.0f));

	////��������Ԫ��opengl����֧��16������Ԫ��0������ԪĬ�ϼ���
	//glActiveTexture(GL_TEXTURE0);
	////�����������shader���ȡ��texture������󶨶��������ͷ��ж���Ч��ֱ���������°��µ�����
	////glBindTexture(GL_TEXTURE_2D, _textureBox);
	
	
	// --- ��Ⱦ�ڶ�Ч�� ---
	_shader_blackhole.start(); // ���úڶ���ɫ��
	float rs = 1.0f;
	float m_val = rs / 2.0f;
	// --- ���� Uniforms ---
	_shader_blackhole.setVec3("iResolution", glm::vec3(_width, _height, 0.0f));
	_shader_blackhole.setFloat("iTime", (float)glfwGetTime());
	// ��������ͼ�������ڼ������������ʼ����
	_shader_blackhole.setMatrix("invViewMatrix", invViewMatrix);
	// �����������
	_shader_blackhole.setFloat("SchwarzschildRadius", rs); // ����ʷ�����뾶
	_shader_blackhole.setFloat("M", m_val);

	// ������պ����������
	glActiveTexture(GL_TEXTURE0);                      // ��������Ԫ 0
	glBindTexture(GL_TEXTURE_CUBE_MAP, _textureSky); // ����պ�����
	_shader_blackhole.setInt("skyboxSampler", 0);      // ���� shader skybox �ڵ�Ԫ 0

	// --- ����ȫ������ ---
	glBindVertexArray(VAO_fullscreen_quad);       // �� VAO
	glDrawArrays(GL_TRIANGLES, 0, 6);             // ���ƴ���Ƭ����ɫ��
	glBindVertexArray(0);                         // ��� VAO

	_shader_blackhole.end();

	////������ƽ������Ѱ�ң�������CUBE_MAPѰ�ң�����������_textureSky��������һЩ�������ں��ӵķ���Ч��
	//glBindTexture(GL_TEXTURE_2D, _textureMilkway);


	////��shader������������ǵ���������glsl�ļ�
	//_shader_env.start();
	//_shader_env.setMatrix("_modelMatrix", _modelMatrix);
	//_shader_env.setMatrix("_viewMatrix", _camera.getMatrix());
	//_shader_env.setMatrix("_projMatrix", _projMatrix);
	////�����λ�ô����ȥ���ڼ��㷴��
	//_shader_env.setVec3("_viewPos", _camera.getPosition());

	//////���Ƶ���
	//////��VAO
	////glBindVertexArray(VAO_plane);
	//////����
	////glDrawArrays(GL_TRIANGLES, 0, 6);
	//
	////���Ʒ���
	//glBindVertexArray(VAO_R_cube);
	//glDrawArrays(GL_TRIANGLES, 0, 36);


	//////���ƴ���
	////for (std::map<float, glm::vec3>::reverse_iterator _it = _window_sort.rbegin(); _it != _window_sort.rend(); _it++)
	////{
	////	_modelMatrix = glm::mat4(1.0f);
	////	_modelMatrix = glm::translate(_modelMatrix, _it->second);
	////	_shader_env.setMatrix("_modelMatrix", _modelMatrix);
	////	//������
	////	glBindTexture(GL_TEXTURE_2D, _textureWindow);
	////	glBindVertexArray(VAO_window);
	////	glDrawArrays(GL_TRIANGLES, 0, 6);
	////}
	////���shader����
	//_shader_env.end();

	////������պ�
	////��պ������1�������ȣ�������Ȼ������Ĭ�����ҲΪ1����˻��ƻ�����⣨��ΪĬ��������������С��1�Żᱻ���ƣ�����Ҫ����Ȳ��Ժ�������ΪGL_LEQUAL����ʾ���С�ڵ���ʱͨ�����ص��ǵ���ʱҲͨ����
	//glDepthFunc(GL_LEQUAL);
	////��������Ԫ��opengl����֧��16������Ԫ��0������ԪĬ�ϼ���
	//glActiveTexture(GL_TEXTURE0);
	////�����������shader���ȡ��texture������󶨶���պ���Ч��ֱ���������°��µ�����
	//glBindTexture(GL_TEXTURE_CUBE_MAP, _textureSky);
	//_shader_sky.start();
	////ȥ���������λ�ƣ�ֻ������ת
	//glm::mat4 _viewMatrix(glm::mat3(_camera.getMatrix()));
	//_shader_sky.setMatrix("_viewMatrix", _viewMatrix);
	//_shader_sky.setMatrix("_projMatrix", _projMatrix);
	//glBindVertexArray(VAO_sky);
	//glDrawArrays(GL_TRIANGLES, 0, 36);
	//_shader_sky.end();
	//glDepthFunc(GL_LESS);

}

uint createScreenPlane()
{
	uint _VAO = 0;
	uint _VBO = 0;
	glGenVertexArrays(1, &_VAO);
	glBindVertexArray(_VAO);

	glGenBuffers(1, &_VBO);
	glBindBuffer(GL_ARRAY_BUFFER, _VBO);

	float quadVertices[] = {
		-1.0f,  1.0f,  0.0f, 1.0f,
		-1.0f, -1.0f,  0.0f, 0.0f,
		 1.0f, -1.0f,  1.0f, 0.0f,

		-1.0f,  1.0f,  0.0f, 1.0f,
		 1.0f, -1.0f,  1.0f, 0.0f,
		 1.0f,  1.0f,  1.0f, 1.0f
	};

	glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
	glEnableVertexAttribArray(1);
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));

	return _VAO;
}

//������������
//��vbo��vao �йصĲ�����������
//1����ȡvbo��index��2����vbo��index��3����vbo�����Դ�ռ� �������ݣ�4������shader���ݽ�����ʽ��5������ê��layout
//�õ�һ��VAO
uint createModel()
{
	uint _VAO = 0;
	uint _VBO = 0;
	//��ģ�Ͷ��㹹��vbo
	float vertices[] =
	{
		-0.5f, -0.5f, -0.5f,  0.0f, 0.0f,		0.0f,  0.0f, -1.0f,
		 0.5f, -0.5f, -0.5f,  1.0f, 0.0f,		0.0f,  0.0f, -1.0f,
		 0.5f,  0.5f, -0.5f,  1.0f, 1.0f,		0.0f,  0.0f, -1.0f,
		 0.5f,  0.5f, -0.5f,  1.0f, 1.0f,		0.0f,  0.0f, -1.0f,
		-0.5f,  0.5f, -0.5f,  0.0f, 1.0f,		0.0f,  0.0f, -1.0f,
		-0.5f, -0.5f, -0.5f,  0.0f, 0.0f,		0.0f,  0.0f, -1.0f,

		-0.5f, -0.5f,  0.5f,  0.0f, 0.0f,		0.0f,  0.0f,  1.0f,
		 0.5f, -0.5f,  0.5f,  1.0f, 0.0f,		0.0f,  0.0f,  1.0f,
		 0.5f,  0.5f,  0.5f,  1.0f, 1.0f,		0.0f,  0.0f,  1.0f,
		 0.5f,  0.5f,  0.5f,  1.0f, 1.0f,		0.0f,  0.0f,  1.0f,
		-0.5f,  0.5f,  0.5f,  0.0f, 1.0f,		0.0f,  0.0f,  1.0f,
		-0.5f, -0.5f,  0.5f,  0.0f, 0.0f,		0.0f,  0.0f,  1.0f,

		-0.5f,  0.5f,  0.5f,  1.0f, 0.0f,		-1.0f,  0.0f,  0.0f,
		-0.5f,  0.5f, -0.5f,  1.0f, 1.0f,		-1.0f,  0.0f,  0.0f,
		-0.5f, -0.5f, -0.5f,  0.0f, 1.0f,		-1.0f,  0.0f,  0.0f,
		-0.5f, -0.5f, -0.5f,  0.0f, 1.0f,		-1.0f,  0.0f,  0.0f,
		-0.5f, -0.5f,  0.5f,  0.0f, 0.0f,		-1.0f,  0.0f,  0.0f,
		-0.5f,  0.5f,  0.5f,  1.0f, 0.0f,		-1.0f,  0.0f,  0.0f,

		 0.5f,  0.5f,  0.5f,  1.0f, 0.0f,		1.0f,  0.0f,  0.0f,
		 0.5f,  0.5f, -0.5f,  1.0f, 1.0f,		1.0f,  0.0f,  0.0f,
		 0.5f, -0.5f, -0.5f,  0.0f, 1.0f,		1.0f,  0.0f,  0.0f,
		 0.5f, -0.5f, -0.5f,  0.0f, 1.0f,		1.0f,  0.0f,  0.0f,
		 0.5f, -0.5f,  0.5f,  0.0f, 0.0f,		1.0f,  0.0f,  0.0f,
		 0.5f,  0.5f,  0.5f,  1.0f, 0.0f,		1.0f,  0.0f,  0.0f,

		-0.5f, -0.5f, -0.5f,  0.0f, 1.0f,		0.0f, -1.0f,  0.0f,
		 0.5f, -0.5f, -0.5f,  1.0f, 1.0f,		0.0f, -1.0f,  0.0f,
		 0.5f, -0.5f,  0.5f,  1.0f, 0.0f,		0.0f, -1.0f,  0.0f,
		 0.5f, -0.5f,  0.5f,  1.0f, 0.0f,		0.0f, -1.0f,  0.0f,
		-0.5f, -0.5f,  0.5f,  0.0f, 0.0f,		0.0f, -1.0f,  0.0f,
		-0.5f, -0.5f, -0.5f,  0.0f, 1.0f,		0.0f, -1.0f,  0.0f,

		-0.5f,  0.5f, -0.5f,  0.0f, 1.0f,		0.0f,  1.0f,  0.0f,
		 0.5f,  0.5f, -0.5f,  1.0f, 1.0f,		0.0f,  1.0f,  0.0f,
		 0.5f,  0.5f,  0.5f,  1.0f, 0.0f,		0.0f,  1.0f,  0.0f,
		 0.5f,  0.5f,  0.5f,  1.0f, 0.0f,		0.0f,  1.0f,  0.0f,
		-0.5f,  0.5f,  0.5f,  0.0f, 0.0f,		0.0f,  1.0f,  0.0f,
		-0.5f,  0.5f, -0.5f,  0.0f, 1.0f,		0.0f,  1.0f,  0.0f
	};


	//�������VAO���ɣ���ΪVBO������VAO��
	glGenVertexArrays(1, &_VAO);
	glBindVertexArray(_VAO);



	//ǰ���1��ʾһ��ģ��
	glGenBuffers(1, &_VBO);
	//�󶨣���һ������ָ������һ�����͵�buffer�������GL_ARRAY_BUFFER���������͵�buffer
	glBindBuffer(GL_ARRAY_BUFFER, _VBO);
	//GL_STATIC_DRAW��һλ�ø���OpenGL��δ������ݣ�static��ʾ���ݲ������
	//��һ���ſ�����VBO���Դ�
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
	//��ê����0�����ֻʹ��VBO����VBO2�Ḳ��VBO��ê���㣬����ֻ�ܻ���һ�������Ρ�
	//ʹ��VAO���Ա���������⣬VAO��¼��ê������Ϣ
	//����1��ê��������   2����ê���������м���    3����������     4���Ƿ��һ��     5��ÿ�β���     6����ʲôλ�ÿ�ʼ
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(sizeof(float) * 3));
	glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(sizeof(float) * 5));
	//����ê��0
	glEnableVertexAttribArray(0);
	//����ê��1
	glEnableVertexAttribArray(1);
	glEnableVertexAttribArray(2);
	//�����
	glBindVertexArray(0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	return _VAO;

}

uint createPlane()
{
	uint _VAO = 0;
	uint _VBO = 0;
	glGenVertexArrays(1, &_VAO);
	glBindVertexArray(_VAO);

	glGenBuffers(1, &_VBO);
	glBindBuffer(GL_ARRAY_BUFFER, _VBO);

	float planeVertices[] = {
		 5.0f, -0.5f,  5.0f,  2.0f, 0.0f,
		-5.0f, -0.5f,  5.0f,  0.0f, 0.0f,
		-5.0f, -0.5f, -5.0f,  0.0f, 2.0f,

		 5.0f, -0.5f,  5.0f,  2.0f, 0.0f,
		-5.0f, -0.5f, -5.0f,  0.0f, 2.0f,
		 5.0f, -0.5f, -5.0f,  2.0f, 2.0f
	};
	glBufferData(GL_ARRAY_BUFFER, sizeof(planeVertices), planeVertices, GL_STATIC_DRAW);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
	glEnableVertexAttribArray(1);
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));

	return _VAO;
}


uint createWindow()
{
	uint _VAO = 0;
	uint _VBO = 0;
	glGenVertexArrays(1, &_VAO);
	glBindVertexArray(_VAO);

	glGenBuffers(1, &_VBO);
	glBindBuffer(GL_ARRAY_BUFFER, _VBO);

	float transparentVertices[] = {
		0.0f,  0.5f,  0.0f,  0.0f,  0.0f,
		0.0f, -0.5f,  0.0f,  0.0f,  1.0f,
		1.0f, -0.5f,  0.0f,  1.0f,  1.0f,

		0.0f,  0.5f,  0.0f,  0.0f,  0.0f,
		1.0f, -0.5f,  0.0f,  1.0f,  1.0f,
		1.0f,  0.5f,  0.0f,  1.0f,  0.0f
	};
	glBufferData(GL_ARRAY_BUFFER, sizeof(transparentVertices), transparentVertices, GL_STATIC_DRAW);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
	glEnableVertexAttribArray(1);
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));

	return _VAO;
}


uint createTexture(const char* _fileName)
{
	_pImage = ffImage::readFromFile(_fileName);
	uint _texture = 0;
	//�Ȼ�ȡһ������
	glGenTextures(1, &_texture);
	//����һ������
	glBindTexture(GL_TEXTURE_2D, _texture);
	//S\T������������߽�����ظ�����
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	//����Ŵ󣨷ֱ��ʲ��䣩ʱ�������Բ�ֵ����Сʱ���þͽ�����
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	//�������������
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _pImage->getWidth(), _pImage->getHeight(), 0, GL_RGBA, GL_UNSIGNED_BYTE, _pImage->getData());

	return _texture;
}
//����chubemap������ȥ������պе�VAO
uint createSkyBoxTex()
{
	uint _tid = 0;
	//�Ȼ�ȡһ������
	glGenTextures(1, &_tid);
	//����һ������
	glBindTexture(GL_TEXTURE_2D, _tid);

	std::vector<std::string> _facePath =
	{
			"res/skybox/right.jpg",
			"res/skybox/left.jpg",
			"res/skybox/top.jpg",
			"res/skybox/bottom.jpg",
			"res/skybox/front.jpg",
			"res/skybox/back.jpg"
	};
	for (int i = 0; i < 6; i++)
	{
		_pImage = ffImage::readFromFile(_facePath[i].c_str());
		glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGBA, _pImage->getWidth(), _pImage->getHeight(), 0, GL_RGBA, GL_UNSIGNED_BYTE, _pImage->getData());
		delete _pImage;
	}
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	return _tid;
}
//������պе�VAO,����ȥ��mian��������ã�ʵ����
uint createSkyBoxVAO()
{
	uint _VAO = 0;
	uint _VBO = 0;
	//��ģ�Ͷ��㹹��vbo
	float skyboxVertices[] = {
		// positions          
		-1.0f,  1.0f, -1.0f,
		-1.0f, -1.0f, -1.0f,
		 1.0f, -1.0f, -1.0f,
		 1.0f, -1.0f, -1.0f,
		 1.0f,  1.0f, -1.0f,
		-1.0f,  1.0f, -1.0f,

		-1.0f, -1.0f,  1.0f,
		-1.0f, -1.0f, -1.0f,
		-1.0f,  1.0f, -1.0f,
		-1.0f,  1.0f, -1.0f,
		-1.0f,  1.0f,  1.0f,
		-1.0f, -1.0f,  1.0f,

		 1.0f, -1.0f, -1.0f,
		 1.0f, -1.0f,  1.0f,
		 1.0f,  1.0f,  1.0f,
		 1.0f,  1.0f,  1.0f,
		 1.0f,  1.0f, -1.0f,
		 1.0f, -1.0f, -1.0f,

		-1.0f, -1.0f,  1.0f,
		-1.0f,  1.0f,  1.0f,
		 1.0f,  1.0f,  1.0f,
		 1.0f,  1.0f,  1.0f,
		 1.0f, -1.0f,  1.0f,
		-1.0f, -1.0f,  1.0f,

		-1.0f,  1.0f, -1.0f,
		 1.0f,  1.0f, -1.0f,
		 1.0f,  1.0f,  1.0f,
		 1.0f,  1.0f,  1.0f,
		-1.0f,  1.0f,  1.0f,
		-1.0f,  1.0f, -1.0f,

		-1.0f, -1.0f, -1.0f,
		-1.0f, -1.0f,  1.0f,
		 1.0f, -1.0f, -1.0f,
		 1.0f, -1.0f, -1.0f,
		-1.0f, -1.0f,  1.0f,
		 1.0f, -1.0f,  1.0f
	};


	//�������VAO���ɣ���ΪVBO������VAO��
	glGenVertexArrays(1, &_VAO);
	glBindVertexArray(_VAO);



	//ǰ���1��ʾһ��ģ��
	glGenBuffers(1, &_VBO);
	//�󶨣���һ������ָ������һ�����͵�buffer�������GL_ARRAY_BUFFER���������͵�buffer
	glBindBuffer(GL_ARRAY_BUFFER, _VBO);
	//GL_STATIC_DRAW��һλ�ø���OpenGL��δ������ݣ�static��ʾ���ݲ������
	//��һ���ſ�����VBO���Դ�
	glBufferData(GL_ARRAY_BUFFER, sizeof(skyboxVertices), skyboxVertices, GL_STATIC_DRAW);
	//��ê����0�����ֻʹ��VBO����VBO2�Ḳ��VBO��ê���㣬����ֻ�ܻ���һ�������Ρ�
	//ʹ��VAO���Ա���������⣬VAO��¼��ê������Ϣ
	//����1��ê��������   2����ê���������м���    3����������     4���Ƿ��һ��     5��ÿ�β���     6����ʲôλ�ÿ�ʼ
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
	//����ê��0
	glEnableVertexAttribArray(0);
	//�����
	glBindVertexArray(0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	return _VAO;
}

uint createRefVAO()
{
	uint _VAO = 0;
	uint _VBO = 0;
	//��ģ�Ͷ��㹹��vbo
	float vertices[] =
	{
		-0.5f, -0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
		 0.5f, -0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
		 0.5f,  0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
		 0.5f,  0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
		-0.5f,  0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
		-0.5f, -0.5f, -0.5f,  0.0f,  0.0f, -1.0f,

		-0.5f, -0.5f,  0.5f,  0.0f,  0.0f,  1.0f,
		 0.5f, -0.5f,  0.5f,  0.0f,  0.0f,  1.0f,
		 0.5f,  0.5f,  0.5f,  0.0f,  0.0f,  1.0f,
		 0.5f,  0.5f,  0.5f,  0.0f,  0.0f,  1.0f,
		-0.5f,  0.5f,  0.5f,  0.0f,  0.0f,  1.0f,
		-0.5f, -0.5f,  0.5f,  0.0f,  0.0f,  1.0f,

		-0.5f,  0.5f,  0.5f,  -1.0f,  0.0f,  0.0f,
		-0.5f,  0.5f, -0.5f,  -1.0f,  0.0f,  0.0f,
		-0.5f, -0.5f, -0.5f,  -1.0f,  0.0f,  0.0f,
		-0.5f, -0.5f, -0.5f,  -1.0f,  0.0f,  0.0f,
		-0.5f, -0.5f,  0.5f,  -1.0f,  0.0f,  0.0f,
		-0.5f,  0.5f,  0.5f,  -1.0f,  0.0f,  0.0f,

		 0.5f,  0.5f,  0.5f,  1.0f,  0.0f,  0.0f,
		 0.5f,  0.5f, -0.5f,  1.0f,  0.0f,  0.0f,
		 0.5f, -0.5f, -0.5f,  1.0f,  0.0f,  0.0f,
		 0.5f, -0.5f, -0.5f,  1.0f,  0.0f,  0.0f,
		 0.5f, -0.5f,  0.5f,  1.0f,  0.0f,  0.0f,
		 0.5f,  0.5f,  0.5f,  1.0f,  0.0f,  0.0f,

		-0.5f, -0.5f, -0.5f,  0.0f, -1.0f,  0.0f,
		 0.5f, -0.5f, -0.5f,  0.0f, -1.0f,  0.0f,
		 0.5f, -0.5f,  0.5f,  0.0f, -1.0f,  0.0f,
		 0.5f, -0.5f,  0.5f,  0.0f, -1.0f,  0.0f,
		-0.5f, -0.5f,  0.5f,  0.0f, -1.0f,  0.0f,
		-0.5f, -0.5f, -0.5f,  0.0f, -1.0f,  0.0f,

		-0.5f,  0.5f, -0.5f,  0.0f,  1.0f,  0.0f,
		 0.5f,  0.5f, -0.5f,  0.0f,  1.0f,  0.0f,
		 0.5f,  0.5f,  0.5f,  0.0f,  1.0f,  0.0f,
		 0.5f,  0.5f,  0.5f,  0.0f,  1.0f,  0.0f,
		-0.5f,  0.5f,  0.5f,  0.0f,  1.0f,  0.0f,
		-0.5f,  0.5f, -0.5f,  0.0f,  1.0f,  0.0f
	};


	//�������VAO���ɣ���ΪVBO������VAO��
	glGenVertexArrays(1, &_VAO);
	glBindVertexArray(_VAO);



	//ǰ���1��ʾһ��ģ��
	glGenBuffers(1, &_VBO);
	//�󶨣���һ������ָ������һ�����͵�buffer�������GL_ARRAY_BUFFER���������͵�buffer
	glBindBuffer(GL_ARRAY_BUFFER, _VBO);
	//GL_STATIC_DRAW��һλ�ø���OpenGL��δ������ݣ�static��ʾ���ݲ������
	//��һ���ſ�����VBO���Դ�
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
	//��ê����0�����ֻʹ��VBO����VBO2�Ḳ��VBO��ê���㣬����ֻ�ܻ���һ�������Ρ�
	//ʹ��VAO���Ա���������⣬VAO��¼��ê������Ϣ
	//����1��ê��������   2����ê���������м���    3����������     4���Ƿ��һ��     5��ÿ�β���     6����ʲôλ�ÿ�ʼ
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(sizeof(float) * 3));
	//����ê��0
	glEnableVertexAttribArray(0);
	//����ê��1
	glEnableVertexAttribArray(1);
	//�����
	glBindVertexArray(0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	return _VAO;
}

uint createFullscreenQuadVAO() {
	uint VAO, VBO;
	float quadVertices[] = {
		// positions
		-1.0f,  1.0f, 0.0f,
		-1.0f, -1.0f, 0.0f,
		 1.0f, -1.0f, 0.0f,

		-1.0f,  1.0f, 0.0f,
		 1.0f, -1.0f, 0.0f,
		 1.0f,  1.0f, 0.0f,
	};
	glGenVertexArrays(1, &VAO);
	glGenBuffers(1, &VBO);
	glBindVertexArray(VAO);
	glBindBuffer(GL_ARRAY_BUFFER, VBO);
	glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), &quadVertices, GL_STATIC_DRAW);
	glEnableVertexAttribArray(0); // λ������ location = 0
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
	glBindVertexArray(0);
	// glBindBuffer(GL_ARRAY_BUFFER, 0); // VAO���ʱͨ������Ҫ���VBO
	return VAO;
}

//��ȡshder�ļ���Ȼ�����������shader����glsl��
void initShader()
{
	//_shader.initShader("shader/vertexShader.glsl", "shader/fragmentShader.glsl");
	_shader_sky.initShader("shader/skyShaderv.glsl", "shader/skyShaderf.glsl");
	//_shader_env.initShader("shader/envShaderv.glsl", "shader/envShaderf.glsl");
	_shader_blackhole.initShader("shader/blackholev.glsl", "shader/blackholef.glsl");
}

int main()
{

	//��ʼ��״̬��
	glfwInit();
	//ָ��OpenGL�����汾��
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	//ָ��OpenGL�Ĵΰ汾��
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	// ����profile
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	//���ڲ��ɵ�����С
	glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

	GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "opengl32", NULL, NULL);
	if (window == NULL)
	{
		std::cout << "faild to create glfw window.\n";
		glfwTerminate();
		return -1;
	}
	//�������֮����Ҫ�õ�ǰ���ڵĻ����ڵ�ǰ�߳��ϳ�Ϊ��ǰ���������ǽ������Ļ�ͼ���ử�����Ǹոմ����Ĵ�����
	glfwMakeContextCurrent(window);

	//gladѰ��opengl�ĺ�����ַ������opengl�ĺ���ǰ��Ҫ��ʼ��glad
	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
	{
		std::cout << "Failed to initialize GLAD" << std::endl;
		return -1;
	}
	glViewport(0, 0, WIDTH, HEIGHT);
	//����GLFW����ϣ��ÿ�����ڵ�����С��ʱ������������
	glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
	//�趨��겻�ɼ�
	glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
	//�趨����ƶ��¼�
	glfwSetCursorPosCallback(window, mouse_callback);


	//camera�ĳ�ʼ��
	_camera.lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, -1.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.setSpeed(0.01f);

	//VAO_cube = createModel();
	////��ʼ����պе�VAO
	//VAO_sky = createSkyBoxVAO();
	//VAO_R_cube = createRefVAO();


	//_textureBox = createTexture("res/box.png");
	////��ʼ����պе�������ͼ
	//_textureSky = createSkyBoxTex();
	////_textureWindow = createTexture("res/blend_window.png");
	//_textureMilkway = createTexture("res/blackhole/milky_way_nasa.png");
	_textureSky = createSkyBoxTex(); // ������պ��������
	VAO_fullscreen_quad = createFullscreenQuadVAO(); // ����ȫ������ VAO
	initShader();


	/*******************************************��Ⱦѭ��************************************************/
	//glfwWindowShouldClose()��鴰���Ƿ���Ҫ�رա�����ǣ���Ϸѭ���ͽ����ˣ����������ǽ���������Դ����������
	while (!glfwWindowShouldClose(window))
	{
		//��Ӧ��������
		processInput(window);
		//����rend������ͼ
		rend();
		//������ɫ���� 
		glfwSwapBuffers(window);
		//�����¼�
		glfwPollEvents();
	}
	glfwTerminate();
	return 0;
}
