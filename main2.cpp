#include"Base.h"
#include"Shader.h"
#include"ffImage.h"
#include"Camera.h"
using namespace std;



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
uint VAO_sun = 0;
Shader  _shader_cube;
Shader  _shader_sun;
glm::vec3 light_pos(1.0f);
glm::vec3 light_color(1.0f);



unsigned int _texture = 0;
//����ȫ�ֵ�image
ffImage*  _pImage = NULL;


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
	//���������ɫ
	glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
	//�����ǰ���ڣ�����ɫ����Ϊ�����ɫ,�����Ȼ���
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	//��ȼ��
	glEnable(GL_DEPTH_TEST);

	glm::vec3 modelVecs[] = {
	glm::vec3(0.0f,  0.0f,  0.0f),
	glm::vec3(2.0f,  5.0f, -15.0f),
	glm::vec3(-1.5f, -2.2f, -2.5f),
	glm::vec3(-3.8f, -2.0f, -12.3f),
	glm::vec3(2.4f, -0.4f, -3.5f),
	glm::vec3(-1.7f,  3.0f, -7.5f),
	glm::vec3(1.3f, -2.0f, -2.5f),
	glm::vec3(1.5f,  2.0f, -2.5f),
	glm::vec3(1.5f,  0.2f, -1.5f),
	glm::vec3(-1.3f,  1.0f, -1.5f)
	};

	//����1���۾���λ��    2�������ĸ�����    3���Դ����Ϸ���ʲô����
	//_viewMatrix = glm::lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.update();
	
	//����1���ӳ��Ƕ�fov 2����߱�    3����ƽ��   4��Զƽ��
	_projMatrix = glm::perspective(glm::radians(45.0f), (float)_width / (float)_height, 0.1f, 100.0f);
	glBindTexture(GL_TEXTURE_2D, _texture);


	glm::mat4 _modelMatrix(1.0f);
	//����1�����ĸ��������translate   2������ʲôtranslate 
	_modelMatrix = glm::translate(_modelMatrix, glm::vec3(0.0f , 0.0f , -3.0f));
	_modelMatrix = glm::rotate(_modelMatrix, glm::radians((float)glfwGetTime() * 10) , glm::vec3(0.0f , 1.0f , 0.0f));
	//��shader������������ǵ���������glsl�ļ�
	_shader_cube.start();
		_shader_cube.setVec3("view_pos", _camera.getPosition());	
		_shader_cube.setMatrix("_modelMatrix", _modelMatrix);
		_shader_cube.setMatrix("_viewMatrix", _camera.getMatrix());
		_shader_cube.setMatrix("_projMatrix", _projMatrix);
		//�����������
		_shader_cube.setVec3("myLight.m_ambient", light_color * glm::vec3(0.1f));
		_shader_cube.setVec3("myLight.m_diffuse", light_color * glm::vec3(0.7f));
		_shader_cube.setVec3("myLight.m_specular", light_color * glm::vec3(0.5f));
		_shader_cube.setVec3("myLight.m_pos", light_pos);

		//�����������
		_shader_cube.setVec3("myMaterial.m_ambient", glm::vec3(0.1f));
		_shader_cube.setVec3("myMaterial.m_diffuse", glm::vec3(0.7f));
		_shader_cube.setVec3("myMaterial.m_specular", glm::vec3(0.8f));
		_shader_cube.setFloat("myMaterial.m_shiness", 32);
		//��ͼ֮ǰҪ֪������ĸ�VAO��ͼ���Ȱ�VAO
		glBindVertexArray(VAO_cube);
		 
		//�趨Ϊ������������Ƴ������Σ��ӵ�0���㿪ʼ����Ч��Ϊ3��
		glDrawArrays(GL_TRIANGLES, 0, 36);
		//glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
			
		
	//���shader����
	_shader_cube.end();


	_shader_sun.start();
		_shader_sun.setMatrix("_modelMatrix", _modelMatrix);
		_shader_sun.setMatrix("_viewMatrix", _camera.getMatrix());
		_shader_sun.setMatrix("_projMatrix", _projMatrix);
		_modelMatrix = glm::mat4(1.0f);
		//_modelMatrix �������Ѿ���-z������3���������̳�ǰ����ƶ���������glm::mat4(1.0f)��ʼ��
		_modelMatrix = glm::translate(_modelMatrix, light_pos);
		_shader_sun.setMatrix("_modelMatrix", _modelMatrix);
		glBindVertexArray(VAO_sun);
		glDrawArrays(GL_TRIANGLES, 0, 36);
	//���shader����
	_shader_sun.end();


	
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
		- 0.5f,  0.5f, -0.5f,  1.0f, 1.0f,		-1.0f,  0.0f,  0.0f,
		- 0.5f, -0.5f, -0.5f,  0.0f, 1.0f,		-1.0f,  0.0f,  0.0f,
		- 0.5f, -0.5f, -0.5f,  0.0f, 1.0f,		-1.0f,  0.0f,  0.0f,
		- 0.5f, -0.5f,  0.5f,  0.0f, 0.0f,		-1.0f,  0.0f,  0.0f,
		- 0.5f,  0.5f,  0.5f,  1.0f, 0.0f,		-1.0f,  0.0f,  0.0f,

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

void initTexture()
{
	_pImage = ffImage::readFromFile("res/wall.jpg");
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


}

//��ȡshder�ļ���Ȼ�����������shader����glsl��
void initShader(const char* _vertexPath, const char* _fragPath)
{
	_shader_cube.initShader(_vertexPath, _fragPath);
	_shader_sun.initShader("vsunShader.glsl", "fsunShader.glsl");
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

	GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "opengl32", nullptr, nullptr);
	if (window == nullptr)
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
	VAO_cube = createModel();
	VAO_sun = createModel();
	light_pos = glm::vec3(3.0f , 0.0 , -1.0f);
	light_color = glm::vec3(1.0f, 1.0, 1.0f);
	initTexture();
	initShader("vertexShader.glsl", "fragmentShader.glsl");


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
