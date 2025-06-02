#include"Base.h"
#include"Shader.h"
#include"ffImage.h"
#include"Camera.h"
#include <vector>
#include <map>
using namespace std;
//ʹͼ


//
//���û��ı䴰�ڵĴ�С��ʱ���ӿ�ҲӦ�ñ�������
//�Դ���ע��һ���ص�����(Callback Function)��������ÿ�δ��ڴ�С��������ʱ�򱻵���
void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
	//glViewport����ǰ�����������ƴ������½ǵ�λ�á��������͵��ĸ�����������Ⱦ���ڵĿ��Ⱥ͸߶ȣ����أ�
	glViewport(0, 0, width, height);
}


/*******************************************���峣��************************************************/
//���ô��ڵĿ��͸�
const unsigned int WIDTH = 3440;
const unsigned int HEIGHT = 1440;
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

//�ڶ�����λ��
glm::vec3 blackhole_center_world = glm::vec3(0.0f, 0.0f, 0.0f); // Ĭ��������ԭ��


double lastTimeForFPS = 0.0; // �ϴμ��� FPS ��ʱ��� (��)
int nbFrames = 0;         // �ڵ�ǰ���������ڵ�֡��
float time_previous = -1;
float fps = 0;
float time_elapsed; // ����һ֡��ȥ��ʱ�䣬Ҳ�� deltaTime

// ���������Ⱦѭ�� (���� display() ������õĺ���) �Ŀ�ͷ���β
void calculateFPS() {
	// ��ȡ��ǰʱ�� (��)
	double currentTime = glfwGetTime(); // ʹ�� GLFW �ļ�ʱ��
	nbFrames++; // ֡������

	// ÿ�� 1 �����һ�� FPS (����������ϲ����ʱ����)
	if (currentTime - lastTimeForFPS >= 1.0) { // ÿ 1.0 �����һ��
		// printf("%f ms/frame\n", 1000.0/double(nbFrames)); // ��ӡÿ֡��ʱ
		fps = double(nbFrames) / (currentTime - lastTimeForFPS); // ���� FPS
		nbFrames = 0; // ����֡��������
		lastTimeForFPS = currentTime; // �����ϴμ���ʱ��
	}
}
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


	//����1���۾���λ��    2�������ĸ�����    3���Դ����Ϸ���ʲô����
	//_viewMatrix = glm::lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.update();
	glm::mat4 viewMatrix = _camera.getMatrix();
	glm::mat4 invViewMatrix = glm::inverse(viewMatrix);
	
	// --- ��Ⱦ�ڶ�Ч�� ---
	_shader_blackhole.start(); // ���úڶ���ɫ��
	float rs = 1.0f;
	float m_val = rs / 2.0f;
	// --- ���� Uniforms ---
	_shader_blackhole.setVec3("iResolution", glm::vec3(_width, _height, 0.0f));
	_shader_blackhole.setFloat("iTime", (float)glfwGetTime());
	// ��������ͼ�������ڼ������������ʼ����
	_shader_blackhole.setMatrix("invViewMatrix", invViewMatrix);
	// ������������
	_shader_blackhole.setFloat("SchwarzschildRadius", rs); // ����ʷ�����뾶
	_shader_blackhole.setFloat("M", m_val);
	_shader_blackhole.setVec3("blackholeCenterWorld", blackhole_center_world);
	// ������պ�����������
	glActiveTexture(GL_TEXTURE0);                      // ����������Ԫ 0
	glBindTexture(GL_TEXTURE_CUBE_MAP, _textureSky); // ����պ�����
	_shader_blackhole.setInt("skyboxSampler", 0);      // ���� shader skybox �ڵ�Ԫ 0

	// --- ����ȫ������ ---
	glBindVertexArray(VAO_fullscreen_quad);       // �� VAO
	glDrawArrays(GL_TRIANGLES, 0, 6);             // ���ƴ���Ƭ����ɫ��
	glBindVertexArray(0);                         // ��� VAO

	_shader_blackhole.end();

	float distance_to_blackhole = glm::length(_camera.getPosition() - blackhole_center_world);
	static int frame_count_for_print = 0;
	const int print_interval_frames = 30; // ÿ 30 ֡��ӡһ��
	if (frame_count_for_print % print_interval_frames == 0) {
		// system("cls"); // (Windows) ��տ���̨����ѡ
		printf("--- Frame %d ---\n", frame_count_for_print);
		printf("Distance to BH: %.2f Rs (based on simulation units)\n", distance_to_blackhole / rs); // ���� rs ����ת��Ϊ�� "ʷ�����뾶=1" Ϊ��λ�ı���
		printf("Camera Pos: (%.2f, %.2f, %.2f)\n", _camera.getPosition().x, _camera.getPosition().y, _camera.getPosition().z);
		printf("FPS: %.2f\n", fps); // ���� fps �Ѽ���
	}
	frame_count_for_print++;
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
	//�����Ŵ󣨷ֱ��ʲ��䣩ʱ�������Բ�ֵ����Сʱ���þͽ�����
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	//��������������
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
			"res/skybox3/right.jpg",
			"res/skybox3/left.jpg",
			"res/skybox3/top.jpg",
			"res/skybox3/bottom.jpg",
			"res/skybox3/front.jpg",
			"res/skybox3/back.jpg"
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
	_camera.lookAt(glm::vec3(0.0f, 0.0f, 10.0f), glm::vec3(0.0f, 0.0f, -1.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.setSpeed(0.1f);

	
	_textureSky = createSkyBoxTex(); // ������պ���������
	VAO_fullscreen_quad = createFullscreenQuadVAO(); // ����ȫ������ VAO
	initShader();


	/*******************************************��Ⱦѭ��************************************************/
	//glfwWindowShouldClose()��鴰���Ƿ���Ҫ�رա�����ǣ���Ϸѭ���ͽ����ˣ����������ǽ���������Դ����������
	while (!glfwWindowShouldClose(window))
	{
		double currentFrameTime = glfwGetTime();
		if (time_previous < 0) time_previous = currentFrameTime; // time_previous ӦΪ double
		time_elapsed = static_cast<float>(currentFrameTime - time_previous); // time_elapsed ��Ϊ float
		time_previous = currentFrameTime;
		// --- deltaTime ������� ---

		calculateFPS(); // ���� FPS
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
