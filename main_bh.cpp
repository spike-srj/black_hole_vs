#include"Base.h"
#include"Shader.h"
#include"ffImage.h"
#include"Camera.h"
#include <vector>
#include <map>
#include <GL/glut.h>
using namespace std;
//材质光照贴图


//
//当用户改变窗口的大小的时候，视口也应该被调整。
//对窗口注册一个回调函数(Callback Function)，它会在每次窗口大小被调整的时候被调用
void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
	//glViewport函数前两个参数控制窗口左下角的位置。第三个和第四个参数控制渲染窗口的宽度和高度（像素）
	glViewport(0, 0, width, height);
}


/*******************************************定义常量************************************************/
//设置窗口的宽和高
const unsigned int WIDTH = 3440;
const unsigned int HEIGHT = 1440;
int _width = WIDTH;
int _height = HEIGHT;

uint VAO_cube = 0;
uint VAO_sky = 0; 
uint VAO_fullscreen_quad = 0; // 用于触发黑洞片段着色器
//uint VAO_plane = 0;
//uint VAO_window = 0;
//uint VAO_screen = 0;
uint VAO_R_cube = 0;

ffImage* _pImage = NULL;

//声明shader
Shader  _shader;
Shader  _shader_sky;
Shader  _shader_env;
Shader  _shader_blackhole;

//光照贴图
uint            _textureBox = 0;
uint            _textureSky = 0;
uint            _textureMilkway = 0;


Camera  _camera;
//glm::mat4 _viewMatrix(1.0f);
glm::mat4 _projMatrix(1.0f);

//黑洞中心位置
glm::vec3 blackhole_center_world = glm::vec3(0.0f, 0.0f, 0.0f); // 默认在世界原点


double lastTimeForFPS = 0.0; // 上次计算 FPS 的时间点 (秒)
int nbFrames = 0;         // 在当前计算周期内的帧数
float time_previous = -1;
float fps = 0;
float time_elapsed; // 自上一帧过去的时间，也叫 deltaTime

// 在你的主渲染循环 (例如 display() 或其调用的函数) 的开头或结尾
void calculateFPS() {
	// 获取当前时间 (秒)
	double currentTime = glfwGetTime(); // 使用 GLFW 的计时器
	nbFrames++; // 帧数增加

	// 每隔 1 秒计算一次 FPS (或者其他你喜欢的时间间隔)
	if (currentTime - lastTimeForFPS >= 1.0) { // 每 1.0 秒计算一次
		// printf("%f ms/frame\n", 1000.0/double(nbFrames)); // 打印每帧耗时
		fps = double(nbFrames) / (currentTime - lastTimeForFPS); // 计算 FPS
		nbFrames = 0; // 重置帧数计数器
		lastTimeForFPS = currentTime; // 更新上次计算时间
	}
}
//响应键盘输入事件
//ESC推出窗口
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
//设定鼠标移动事件, 每次记录上一次xy的位置，对比计算pitch的增量
void mouse_callback(GLFWwindow* window, double xpos, double ypos)
{
	_camera.onMouseMove(xpos, ypos);
}

void rend()
{
	//设置清除颜色
	glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
	//清除当前窗口，把颜色设置为清除颜色,清除深度缓存
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);


	//参数1、眼睛的位置    2、看向哪个方向    3、脑袋的上方是什么方向
	//_viewMatrix = glm::lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.update();
	glm::mat4 viewMatrix = _camera.getMatrix();
	glm::mat4 invViewMatrix = glm::inverse(viewMatrix);
	
	// --- 渲染黑洞效果 ---
	_shader_blackhole.start(); // 启用黑洞着色器
	float rs = 1.0f;
	float m_val = rs / 2.0f;
	// --- 传递 Uniforms ---
	_shader_blackhole.setVec3("iResolution", glm::vec3(_width, _height, 0.0f));
	_shader_blackhole.setFloat("iTime", (float)glfwGetTime());
	// 传递逆视图矩阵，用于计算世界坐标初始条件
	_shader_blackhole.setMatrix("invViewMatrix", invViewMatrix);
	// 传递物理参数
	_shader_blackhole.setFloat("SchwarzschildRadius", rs); // 设置史瓦西半径
	_shader_blackhole.setFloat("M", m_val);
	_shader_blackhole.setVec3("blackholeCenterWorld", blackhole_center_world);
	// 传递天空盒纹理采样器
	glActiveTexture(GL_TEXTURE0);                      // 激活纹理单元 0
	glBindTexture(GL_TEXTURE_CUBE_MAP, _textureSky); // 绑定天空盒纹理
	_shader_blackhole.setInt("skyboxSampler", 0);      // 告诉 shader skybox 在单元 0

	// --- 绘制全屏矩形 ---
	glBindVertexArray(VAO_fullscreen_quad);       // 绑定 VAO
	glDrawArrays(GL_TRIANGLES, 0, 6);             // 绘制触发片段着色器
	glBindVertexArray(0);                         // 解绑 VAO

	_shader_blackhole.end();

	float distance_to_blackhole = glm::length(_camera.getPosition() - blackhole_center_world);
	static int frame_count_for_print = 0;
	const int print_interval_frames = 30; // 每 30 帧打印一次
	if (frame_count_for_print % print_interval_frames == 0) {
		// system("cls"); // (Windows) 清空控制台，可选
		printf("--- Frame %d ---\n", frame_count_for_print);
		printf("Distance to BH: %.2f Rs (based on simulation units)\n", distance_to_blackhole / rs); // 除以 rs 将其转换为以 "史瓦西半径=1" 为单位的倍数
		printf("Camera Pos: (%.2f, %.2f, %.2f)\n", _camera.getPosition().x, _camera.getPosition().y, _camera.getPosition().z);
		printf("FPS: %.2f\n", fps); // 假设 fps 已计算
	}
	frame_count_for_print++;
}


uint createTexture(const char* _fileName)
{
	_pImage = ffImage::readFromFile(_fileName);
	uint _texture = 0;
	//先获取一张纹理
	glGenTextures(1, &_texture);
	//绑定哪一种纹理
	glBindTexture(GL_TEXTURE_2D, _texture);
	//S\T方向如果超出边界采用重复方案
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	//纹理放大（分辨率不变）时采用线性插值，缩小时采用就近采样
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	//这里曾经出错过
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _pImage->getWidth(), _pImage->getHeight(), 0, GL_RGBA, GL_UNSIGNED_BYTE, _pImage->getData());

	return _texture;
}
//构造chubemap，接下去构造天空盒的VAO
uint createSkyBoxTex()
{
	uint _tid = 0;
	//先获取一张纹理
	glGenTextures(1, &_tid);
	//绑定哪一种纹理
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
//构造天空盒的VAO,接下去在mian函数里调用，实例化
uint createSkyBoxVAO()
{
	uint _VAO = 0;
	uint _VBO = 0;
	//用模型顶点构建vbo
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


	//后面调用VAO即可，因为VBO包含在VAO里
	glGenVertexArrays(1, &_VAO);
	glBindVertexArray(_VAO);



	//前面的1表示一个模型
	glGenBuffers(1, &_VBO);
	//绑定，第一个参数指定绑定哪一种类型的buffer，这里的GL_ARRAY_BUFFER是数组类型的buffer
	glBindBuffer(GL_ARRAY_BUFFER, _VBO);
	//GL_STATIC_DRAW这一位置告诉OpenGL如何处理数据，static表示数据不会更改
	//这一步才开辟了VBO的显存
	glBufferData(GL_ARRAY_BUFFER, sizeof(skyboxVertices), skyboxVertices, GL_STATIC_DRAW);
	//绑定锚定点0，如果只使用VBO，那VBO2会覆盖VBO的锚定点，这样只能画出一个三角形。
	//使用VAO可以避免这个问题，VAO记录了锚定点信息
	//参数1、锚定点序列   2、该锚定点数据有几个    3、数据类型     4、是否归一化     5、每次步长     6、从什么位置开始
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
	//启用锚点0
	glEnableVertexAttribArray(0);
	//解除绑定
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
	glEnableVertexAttribArray(0); // 位置属性 location = 0
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
	glBindVertexArray(0);
	// glBindBuffer(GL_ARRAY_BUFFER, 0); // VAO解绑时通常不需要解绑VBO
	return VAO;
}

//读取shder文件，然后编译与链接shader程序（glsl）
void initShader()
{
	//_shader.initShader("shader/vertexShader.glsl", "shader/fragmentShader.glsl");
	_shader_sky.initShader("shader/skyShaderv.glsl", "shader/skyShaderf.glsl");
	//_shader_env.initShader("shader/envShaderv.glsl", "shader/envShaderf.glsl");
	_shader_blackhole.initShader("shader/blackholev.glsl", "shader/blackholef.glsl");
}

int main()
{

	//初始化状态机
	glfwInit();
	//指定OpenGL的主版本号
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	//指定OpenGL的次版本号
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	// 设置profile
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	//窗口不可调整大小
	glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

	GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "opengl32", NULL, NULL);
	if (window == NULL)
	{
		std::cout << "faild to create glfw window.\n";
		glfwTerminate();
		return -1;
	}
	//创建完毕之后，需要让当前窗口的环境在当前线程上成为当前环境，就是接下来的画图都会画在我们刚刚创建的窗口上
	glfwMakeContextCurrent(window);

	//glad寻找opengl的函数地址，调用opengl的函数前需要初始化glad
	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
	{
		std::cout << "Failed to initialize GLAD" << std::endl;
		return -1;
	}
	glViewport(0, 0, WIDTH, HEIGHT);
	//告诉GLFW我们希望每当窗口调整大小的时候调用这个函数
	glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
	//设定鼠标不可见
	glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
	//设定鼠标移动事件
	glfwSetCursorPosCallback(window, mouse_callback);


	//camera的初始化
	_camera.lookAt(glm::vec3(0.0f, 0.0f, 10.0f), glm::vec3(0.0f, 0.0f, -1.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.setSpeed(0.1f);

	
	_textureSky = createSkyBoxTex(); // 保留天空盒纹理加载
	VAO_fullscreen_quad = createFullscreenQuadVAO(); // 创建全屏矩形 VAO
	initShader();


	/*******************************************渲染循环************************************************/
	//glfwWindowShouldClose()检查窗口是否需要关闭。如果是，游戏循环就结束了，接下来我们将会清理资源，结束程序
	while (!glfwWindowShouldClose(window))
	{
		double currentFrameTime = glfwGetTime();
		if (time_previous < 0) time_previous = currentFrameTime; // time_previous 应为 double
		time_elapsed = static_cast<float>(currentFrameTime - time_previous); // time_elapsed 仍为 float
		time_previous = currentFrameTime;
		// --- deltaTime 计算结束 ---

		calculateFPS(); // 计算 FPS
		//响应键盘输入
		processInput(window);
		//调用rend函数绘图
		rend();
		//交换颜色缓冲 
		glfwSwapBuffers(window);
		//处理事件
		glfwPollEvents();
	}
	glfwTerminate();
	return 0;
}
