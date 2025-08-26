#include"Base.h"
#include"Shader.h"
#include"ffImage.h"
#include"Camera.h"
using namespace std;



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
//声明全局的image
ffImage*  _pImage = NULL;


Camera  _camera;
//glm::mat4 _viewMatrix(1.0f);
glm::mat4 _projMatrix(1.0f);



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
	//深度检测
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

	//参数1、眼睛的位置    2、看向哪个方向    3、脑袋的上方是什么方向
	//_viewMatrix = glm::lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.update();
	
	//参数1、视场角度fov 2、宽高比    3、近平面   4、远平面
	_projMatrix = glm::perspective(glm::radians(45.0f), (float)_width / (float)_height, 0.1f, 100.0f);
	glBindTexture(GL_TEXTURE_2D, _texture);


	glm::mat4 _modelMatrix(1.0f);
	//参数1、对哪个矩阵进行translate   2、进行什么translate 
	_modelMatrix = glm::translate(_modelMatrix, glm::vec3(0.0f , 0.0f , -3.0f));
	_modelMatrix = glm::rotate(_modelMatrix, glm::radians((float)glfwGetTime() * 10) , glm::vec3(0.0f , 1.0f , 0.0f));
	//绑定shader程序在这里就是调用那两个glsl文件
	_shader_cube.start();
		_shader_cube.setVec3("view_pos", _camera.getPosition());	
		_shader_cube.setMatrix("_modelMatrix", _modelMatrix);
		_shader_cube.setMatrix("_viewMatrix", _camera.getMatrix());
		_shader_cube.setMatrix("_projMatrix", _projMatrix);
		//传入光照属性
		_shader_cube.setVec3("myLight.m_ambient", light_color * glm::vec3(0.1f));
		_shader_cube.setVec3("myLight.m_diffuse", light_color * glm::vec3(0.7f));
		_shader_cube.setVec3("myLight.m_specular", light_color * glm::vec3(0.5f));
		_shader_cube.setVec3("myLight.m_pos", light_pos);

		//传入物体材质
		_shader_cube.setVec3("myMaterial.m_ambient", glm::vec3(0.1f));
		_shader_cube.setVec3("myMaterial.m_diffuse", glm::vec3(0.7f));
		_shader_cube.setVec3("myMaterial.m_specular", glm::vec3(0.8f));
		_shader_cube.setFloat("myMaterial.m_shiness", 32);
		//绘图之前要知道针对哪个VAO绘图，先绑定VAO
		glBindVertexArray(VAO_cube);
		 
		//设定为将三个顶点绘制成三角形，从第0个点开始，有效点为3个
		glDrawArrays(GL_TRIANGLES, 0, 36);
		//glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
			
		
	//解绑shader程序
	_shader_cube.end();


	_shader_sun.start();
		_shader_sun.setMatrix("_modelMatrix", _modelMatrix);
		_shader_sun.setMatrix("_viewMatrix", _camera.getMatrix());
		_shader_sun.setMatrix("_projMatrix", _projMatrix);
		_modelMatrix = glm::mat4(1.0f);
		//_modelMatrix 在上面已经望-z轴走了3，如果不想继承前面的移动，可以用glm::mat4(1.0f)初始化
		_modelMatrix = glm::translate(_modelMatrix, light_pos);
		_shader_sun.setMatrix("_modelMatrix", _modelMatrix);
		glBindVertexArray(VAO_sun);
		glDrawArrays(GL_TRIANGLES, 0, 36);
	//解绑shader程序
	_shader_sun.end();


	
}
//顶点数据设置
//和vbo、vao 有关的操作都在这里
//1、获取vbo的index；2、绑定vbo的index；3、给vbo分配显存空间 传输数据；4、告诉shader数据解析方式、5、激活锚点layout
//得到一个VAO
uint createModel()
{
	uint _VAO = 0;
	uint _VBO = 0;
	//用模型顶点构建vbo
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


	//后面调用VAO即可，因为VBO包含在VAO里
	glGenVertexArrays(1, &_VAO);
	glBindVertexArray(_VAO);

	

	//前面的1表示一个模型
	glGenBuffers(1, &_VBO);
	//绑定，第一个参数指定绑定哪一种类型的buffer，这里的GL_ARRAY_BUFFER是数组类型的buffer
	glBindBuffer(GL_ARRAY_BUFFER, _VBO);
	//GL_STATIC_DRAW这一位置告诉OpenGL如何处理数据，static表示数据不会更改
	//这一步才开辟了VBO的显存
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
	//绑定锚定点0，如果只使用VBO，那VBO2会覆盖VBO的锚定点，这样只能画出一个三角形。
	//使用VAO可以避免这个问题，VAO记录了锚定点信息
	//参数1、锚定点序列   2、该锚定点数据有几个    3、数据类型     4、是否归一化     5、每次步长     6、从什么位置开始
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(sizeof(float) * 3));
	glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(sizeof(float) * 5));
	//启用锚点0
	glEnableVertexAttribArray(0);
	//启用锚点1
	glEnableVertexAttribArray(1);
	glEnableVertexAttribArray(2);
	//解除绑定
	glBindVertexArray(0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	return _VAO;
	
}

void initTexture()
{
	_pImage = ffImage::readFromFile("res/wall.jpg");
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


}

//读取shder文件，然后编译与链接shader程序（glsl）
void initShader(const char* _vertexPath, const char* _fragPath)
{
	_shader_cube.initShader(_vertexPath, _fragPath);
	_shader_sun.initShader("vsunShader.glsl", "fsunShader.glsl");
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

	GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "opengl32", nullptr, nullptr);
	if (window == nullptr)
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
	_camera.lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, -1.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.setSpeed(0.01f);
	VAO_cube = createModel();
	VAO_sun = createModel();
	light_pos = glm::vec3(3.0f , 0.0 , -1.0f);
	light_color = glm::vec3(1.0f, 1.0, 1.0f);
	initTexture();
	initShader("vertexShader.glsl", "fragmentShader.glsl");


	/*******************************************渲染循环************************************************/
	//glfwWindowShouldClose()检查窗口是否需要关闭。如果是，游戏循环就结束了，接下来我们将会清理资源，结束程序
	while (!glfwWindowShouldClose(window))
	{
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
