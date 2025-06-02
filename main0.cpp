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
const unsigned int WIDTH = 800;
const unsigned int HEIGHT = 600;
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
	////数据
	//std::vector<glm::vec3> _window_pos
	//{
	//	glm::vec3(-1.5f, 0.0f, -0.48f),
	//	glm::vec3(1.5f, 0.0f, 0.51f),
	//	glm::vec3(0.0f, 0.0f, 0.7f),
	//	glm::vec3(-0.3f, 0.0f, -2.3f),
	//	glm::vec3(0.5f, 0.0f, -0.6f)
	//};

	////给窗户排序，离摄像机越近的窗户越后绘制
	//std::map<float, glm::vec3> _window_sort;
	//for (int i = 0; i < _window_pos.size(); i++)
	//{
	//	float _dist = glm::length(_camera.getPosition() - _window_pos[i]);
	//	_window_sort[_dist] = _window_pos[i];
	//}

	//设置清除颜色
	glClearColor(1.f, 0.3f, 0.3f, 1.0f);
	//清除当前窗口，把颜色设置为清除颜色,清除深度缓存
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	//打开深度检测权限，这一项应该在clear前面，打开权限才能clear
	// 深度测试可以禁用，因为我们只画一个全屏效果，或者保留以备将来使用
	//glEnable(GL_DEPTH_TEST);
	////打开blend混合权限
	//glEnable(GL_BLEND);
	////设置混合方式
	//glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);



	//参数1、眼睛的位置    2、看向哪个方向    3、脑袋的上方是什么方向
	//_viewMatrix = glm::lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.update();
	glm::mat4 viewMatrix = _camera.getMatrix();
	glm::mat4 invViewMatrix = glm::inverse(viewMatrix);
	////参数1、视场角度fov 2、宽高比    3、近平面   4、远平面
	//_projMatrix = glm::perspective(glm::radians(45.0f), (float)_width / (float)_height, 0.1f, 100.0f);
	//glm::mat4 _modelMatrix(1.0f);
	////参数1、对哪个矩阵进行translate   2、进行什么translate 
	//_modelMatrix = glm::translate(_modelMatrix, glm::vec3(0.0f, 0.0f, -3.0f));

	////激活纹理单元，opengl至少支持16个纹理单元，0号纹理单元默认激活
	//glActiveTexture(GL_TEXTURE0);
	////绑定纹理。这就是shader里读取的texture，这里绑定对下面地面和方盒都有效，直到窗体重新绑定新的纹理
	////glBindTexture(GL_TEXTURE_2D, _textureBox);
	
	
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

	// 传递天空盒纹理采样器
	glActiveTexture(GL_TEXTURE0);                      // 激活纹理单元 0
	glBindTexture(GL_TEXTURE_CUBE_MAP, _textureSky); // 绑定天空盒纹理
	_shader_blackhole.setInt("skyboxSampler", 0);      // 告诉 shader skybox 在单元 0

	// --- 绘制全屏矩形 ---
	glBindVertexArray(VAO_fullscreen_quad);       // 绑定 VAO
	glDrawArrays(GL_TRIANGLES, 0, 6);             // 绘制触发片段着色器
	glBindVertexArray(0);                         // 解绑 VAO

	_shader_blackhole.end();

	////不是向平面纹理寻找，而是向CUBE_MAP寻找，而进来的是_textureSky，向它做一些采样用于盒子的反射效果
	//glBindTexture(GL_TEXTURE_2D, _textureMilkway);


	////绑定shader程序在这里就是调用那两个glsl文件
	//_shader_env.start();
	//_shader_env.setMatrix("_modelMatrix", _modelMatrix);
	//_shader_env.setMatrix("_viewMatrix", _camera.getMatrix());
	//_shader_env.setMatrix("_projMatrix", _projMatrix);
	////将相机位置传入进去用于计算反射
	//_shader_env.setVec3("_viewPos", _camera.getPosition());

	//////绘制地面
	//////绑定VAO
	////glBindVertexArray(VAO_plane);
	//////绘制
	////glDrawArrays(GL_TRIANGLES, 0, 6);
	//
	////绘制方盒
	//glBindVertexArray(VAO_R_cube);
	//glDrawArrays(GL_TRIANGLES, 0, 36);


	//////绘制窗体
	////for (std::map<float, glm::vec3>::reverse_iterator _it = _window_sort.rbegin(); _it != _window_sort.rend(); _it++)
	////{
	////	_modelMatrix = glm::mat4(1.0f);
	////	_modelMatrix = glm::translate(_modelMatrix, _it->second);
	////	_shader_env.setMatrix("_modelMatrix", _modelMatrix);
	////	//绑定纹理
	////	glBindTexture(GL_TEXTURE_2D, _textureWindow);
	////	glBindVertexArray(VAO_window);
	////	glDrawArrays(GL_TRIANGLES, 0, 6);
	////}
	////解绑shader程序
	//_shader_env.end();

	////绘制天空盒
	////天空盒深度是1（最高深度），而深度缓存里的默认深度也为1，因此绘制会出问题（因为默认情况下物体深度小于1才会被绘制），需要将深度测试函数设置为GL_LEQUAL，表示深度小于等于时通过（重点是等于时也通过）
	//glDepthFunc(GL_LEQUAL);
	////激活纹理单元，opengl至少支持16个纹理单元，0号纹理单元默认激活
	//glActiveTexture(GL_TEXTURE0);
	////绑定纹理。这就是shader里读取的texture，这里绑定对天空盒有效，直到窗体重新绑定新的纹理
	//glBindTexture(GL_TEXTURE_CUBE_MAP, _textureSky);
	//_shader_sky.start();
	////去掉摄像机的位移，只保留旋转
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

uint createRefVAO()
{
	uint _VAO = 0;
	uint _VBO = 0;
	//用模型顶点构建vbo
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
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(sizeof(float) * 3));
	//启用锚点0
	glEnableVertexAttribArray(0);
	//启用锚点1
	glEnableVertexAttribArray(1);
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
	_camera.lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, -1.0f), glm::vec3(0.0f, 1.0f, 0.0f));
	_camera.setSpeed(0.01f);

	//VAO_cube = createModel();
	////初始化天空盒的VAO
	//VAO_sky = createSkyBoxVAO();
	//VAO_R_cube = createRefVAO();


	//_textureBox = createTexture("res/box.png");
	////初始化天空盒的纹理贴图
	//_textureSky = createSkyBoxTex();
	////_textureWindow = createTexture("res/blend_window.png");
	//_textureMilkway = createTexture("res/blackhole/milky_way_nasa.png");
	_textureSky = createSkyBoxTex(); // 保留天空盒纹理加载
	VAO_fullscreen_quad = createFullscreenQuadVAO(); // 创建全屏矩形 VAO
	initShader();


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
