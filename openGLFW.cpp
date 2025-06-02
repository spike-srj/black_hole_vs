#include"Base.h"
#include"Shader.h"
#include"ffImage.h"
#include"Camera.h"

uint VAO_cube = 0;
uint VAO_sun = 0;
glm::vec3 light_pos(1.0f); 
glm::vec3 light_color(1.0f);

/*课程目标
* 1 将每种光照计算效果独立成函数
* 2 设计一个场景，拥有一个平行光，四盏点光源灯 ，一个探照灯
*/

ffImage*    _pImage = NULL;


Shader          _shader_sun;
Shader          _shader_scene;
Shader          _shader_color;


//光照贴图
uint            _textureBox = 0;
uint            _textureSpec = 0;


Camera          _camera;

glm::mat4 _projMatrix(1.0f);
int       _width = 800;
int       _height = 600;

void rend()
{


    glEnable(GL_DEPTH_TEST);
    glEnable(GL_STENCIL_TEST);
    glStencilMask(0xFF);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    
    glm::vec3 cubePositions[] = {
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

    glm::vec3 pointLightPositions[] = {
    glm::vec3(0.7f,  0.2f,  2.0f),
    glm::vec3(2.3f, -3.3f, -4.0f),
    glm::vec3(-4.0f,  2.0f, -12.0f),
    glm::vec3(0.0f,  0.0f, -3.0f)
    };



    _camera.update();
    _projMatrix = glm::perspective(glm::radians(45.0f), (float)_width / (float)_height, 0.1f, 100.0f);
    glm::mat4 _modelMatrix(1.0f);
    _modelMatrix = glm::translate(_modelMatrix, glm::vec3(0.0f, 0.0f, -3.0f));

    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _textureBox);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _textureSpec);

    


    _shader_scene.start();
    _shader_scene.setVec3("view_pos", _camera.getPosition());
 
    //传入物体材质属性
    _shader_scene.setInt("myMaterial.m_specular", 1);
    _shader_scene.setFloat("myMaterial.m_shiness" , 32);
  
    _shader_scene.setMatrix("_viewMatrix", _camera.getMatrix());
    _shader_scene.setMatrix("_projMatrix", _projMatrix);

    // directional light
    _shader_scene.setVec3("_dirLight.m_direction", glm::vec3(-0.2f, -1.0f, -0.3f));
    _shader_scene.setVec3("_dirLight.m_ambient", glm::vec3(0.05f, 0.05f, 0.05f));
    _shader_scene.setVec3("_dirLight.m_diffuse", glm::vec3(0.4f, 0.4f, 0.4f));
    _shader_scene.setVec3("_dirLight.m_specular", glm::vec3(0.5f, 0.5f, 0.5f));
    // point light 1
    _shader_scene.setVec3("_pointLight[0].m_pos", pointLightPositions[0]);
    _shader_scene.setVec3("_pointLight[0].m_ambient", glm::vec3(0.05f, 0.05f, 0.05f));
    _shader_scene.setVec3("_pointLight[0].m_diffuse", glm::vec3(0.8f, 0.8f, 0.8f));
    _shader_scene.setVec3("_pointLight[0].m_specular", glm::vec3(1.0f, 1.0f, 1.0f));
    _shader_scene.setFloat("_pointLight[0].m_c", 1.0f);
    _shader_scene.setFloat("_pointLight[0].m_l", 0.09);
    _shader_scene.setFloat("_pointLight[0].m_q", 0.032);
    // point light 2
    _shader_scene.setVec3("_pointLight[1].m_pos", pointLightPositions[1]);
    _shader_scene.setVec3("_pointLight[1].m_ambient", glm::vec3(0.05f, 0.05f, 0.05f));
    _shader_scene.setVec3("_pointLight[1].m_diffuse", glm::vec3(0.8f, 0.8f, 0.8f));
    _shader_scene.setVec3("_pointLight[1].m_specular", glm::vec3(1.0f, 1.0f, 1.0f));
    _shader_scene.setFloat("_pointLight[1].m_c", 1.0f);
    _shader_scene.setFloat("_pointLight[1].m_l", 0.09);
    _shader_scene.setFloat("_pointLight[1].m_q", 0.032);
    // point light 3
    _shader_scene.setVec3("_pointLight[2].m_pos", pointLightPositions[2]);
    _shader_scene.setVec3("_pointLight[2].m_ambient", glm::vec3(0.05f, 0.05f, 0.05f));
    _shader_scene.setVec3("_pointLight[2].m_diffuse", glm::vec3(0.8f, 0.8f, 0.8f));
    _shader_scene.setVec3("_pointLight[2].m_specular", glm::vec3(1.0f, 1.0f, 1.0f));
    _shader_scene.setFloat("_pointLight[2].m_c", 1.0f);
    _shader_scene.setFloat("_pointLight[2].m_l", 0.09);
    _shader_scene.setFloat("_pointLight[2].m_q", 0.032);
    // point light 4
    _shader_scene.setVec3("_pointLight[3].m_pos", pointLightPositions[3]);
    _shader_scene.setVec3("_pointLight[3].m_ambient", glm::vec3(0.05f, 0.05f, 0.05f));
    _shader_scene.setVec3("_pointLight[3].m_diffuse", glm::vec3(0.8f, 0.8f, 0.8f));
    _shader_scene.setVec3("_pointLight[3].m_specular", glm::vec3(1.0f, 1.0f, 1.0f));
    _shader_scene.setFloat("_pointLight[3].m_c", 1.0f);
    _shader_scene.setFloat("_pointLight[3].m_l", 0.09);
    _shader_scene.setFloat("_pointLight[3].m_q", 0.032);
    // spotLight
    _shader_scene.setVec3("_spotLight.m_pos", _camera.getPosition());
    _shader_scene.setVec3("_spotLight.m_direction", _camera.getDirection());
    _shader_scene.setVec3("_spotLight.m_ambient", glm::vec3(0.0f, 0.0f, 0.0f));
    _shader_scene.setVec3("_spotLight.m_diffuse", glm::vec3(1.0f, 1.0f, 1.0f));
    _shader_scene.setVec3("_spotLight.m_specular", glm::vec3(1.0f, 1.0f, 1.0f));
    _shader_scene.setFloat("_spotLight.m_c", 1.0f);
    _shader_scene.setFloat("_spotLight.m_l", 0.09);
    _shader_scene.setFloat("_spotLight.m_q", 0.032);
    _shader_scene.setFloat("_spotLight.m_cutOff", glm::cos(glm::radians(12.5f)));
    _shader_scene.setFloat("_spotLight.m_outCutOff", glm::cos(glm::radians(15.0f)));

    
    //////绘制方盒
    for (int i = 0; i < 10; i++)
    {
        glStencilFunc(GL_ALWAYS, 1, 0xFF);
        glStencilMask(0x00);
        if (i == 4)
        {
            glStencilFunc(GL_ALWAYS, 1, 0xFF);
            glStencilMask(0xFF);
            glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
        }
        _modelMatrix = glm::mat4(1.0f);
        _modelMatrix = glm::translate(_modelMatrix, cubePositions[i]);
        _modelMatrix = glm::rotate(_modelMatrix, glm::radians(i * 20.0f), glm::vec3(0.0f, 1.0f, 0.0f));

        _shader_scene.setMatrix("_modelMatrix", _modelMatrix);
        glBindVertexArray(VAO_cube);
        glDrawArrays(GL_TRIANGLES, 0, 36);

    }
        
    _shader_scene.end();


    
    //绘制高光边缘
    _shader_color.start();
    _shader_color.setMatrix("_viewMatrix", _camera.getMatrix());
    _shader_color.setMatrix("_projMatrix", _projMatrix);

    //////渲染高光边缘
    for (int i = 0; i < 10; i++)
    {
        glStencilFunc(GL_NEVER, 1, 0xFF);
        glStencilMask(0x00);
        if (i == 4)
        {
            glStencilFunc(GL_NOTEQUAL, 1, 0xFF);
        }
        _modelMatrix = glm::mat4(1.0f);
        _modelMatrix = glm::translate(_modelMatrix, cubePositions[i]);
        _modelMatrix = glm::rotate(_modelMatrix, glm::radians(i * 20.0f), glm::vec3(0.0f, 1.0f, 0.0f));
        _modelMatrix = glm::scale(_modelMatrix, glm::vec3(1.1f, 1.1f, 1.1f));

        _shader_color.setMatrix("_modelMatrix", _modelMatrix);
        glBindVertexArray(VAO_cube);
        glDrawArrays(GL_TRIANGLES, 0, 36);
    }
    _shader_color.end();
   

    glStencilFunc(GL_ALWAYS, 1, 0xFF);
   //////绘制太阳
   _shader_sun.start(); 
   _shader_sun.setMatrix("_viewMatrix", _camera.getMatrix());
   _shader_sun.setMatrix("_projMatrix", _projMatrix);

   for (int i = 0; i < 4; i++)
   {
       _modelMatrix = glm::mat4(1.0f);
       _modelMatrix = glm::translate(_modelMatrix, pointLightPositions[i]);
       _modelMatrix = glm::scale(_modelMatrix, glm::vec3(0.2f, 0.2f, 0.2f));
       _shader_sun.setMatrix("_modelMatrix", _modelMatrix);
       glBindVertexArray(VAO_sun);
       glDrawArrays(GL_TRIANGLES, 0, 36);
   }
   
   _shader_sun.end();
}

uint createModel()
{
    uint _VAO = 0;
    uint _VBO = 0;

    float vertices[] = {
        -0.5f, -0.5f, -0.5f,  0.0f, 0.0f,           0.0f,  0.0f, -1.0f,
         0.5f, -0.5f, -0.5f,  1.0f, 0.0f,           0.0f,  0.0f, -1.0f,
         0.5f,  0.5f, -0.5f,  1.0f, 1.0f,           0.0f,  0.0f, -1.0f,
         0.5f,  0.5f, -0.5f,  1.0f, 1.0f,           0.0f,  0.0f, -1.0f,
        -0.5f,  0.5f, -0.5f,  0.0f, 1.0f,           0.0f,  0.0f, -1.0f,
        -0.5f, -0.5f, -0.5f,  0.0f, 0.0f,           0.0f,  0.0f, -1.0f,

        -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,           0.0f,  0.0f,  1.0f,
         0.5f, -0.5f,  0.5f,  1.0f, 0.0f,           0.0f,  0.0f,  1.0f,
         0.5f,  0.5f,  0.5f,  1.0f, 1.0f,           0.0f,  0.0f,  1.0f,
         0.5f,  0.5f,  0.5f,  1.0f, 1.0f,           0.0f,  0.0f,  1.0f,
        -0.5f,  0.5f,  0.5f,  0.0f, 1.0f,           0.0f,  0.0f,  1.0f,
        -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,           0.0f,  0.0f,  1.0f,

        -0.5f,  0.5f,  0.5f,  1.0f, 0.0f,           -1.0f,  0.0f,  0.0f,
        -0.5f,  0.5f, -0.5f,  1.0f, 1.0f,           -1.0f,  0.0f,  0.0f,
        -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,           -1.0f,  0.0f,  0.0f,
        -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,           -1.0f,  0.0f,  0.0f,
        -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,           -1.0f,  0.0f,  0.0f,
        -0.5f,  0.5f,  0.5f,  1.0f, 0.0f,           -1.0f,  0.0f,  0.0f,

         0.5f,  0.5f,  0.5f,  1.0f, 0.0f,           1.0f,  0.0f,  0.0f,
         0.5f,  0.5f, -0.5f,  1.0f, 1.0f,           1.0f,  0.0f,  0.0f,
         0.5f, -0.5f, -0.5f,  0.0f, 1.0f,           1.0f,  0.0f,  0.0f,
         0.5f, -0.5f, -0.5f,  0.0f, 1.0f,           1.0f,  0.0f,  0.0f,
         0.5f, -0.5f,  0.5f,  0.0f, 0.0f,           1.0f,  0.0f,  0.0f,
         0.5f,  0.5f,  0.5f,  1.0f, 0.0f,           1.0f,  0.0f,  0.0f,

        -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,           0.0f, -1.0f,  0.0f,
         0.5f, -0.5f, -0.5f,  1.0f, 1.0f,           0.0f, -1.0f,  0.0f,
         0.5f, -0.5f,  0.5f,  1.0f, 0.0f,           0.0f, -1.0f,  0.0f,
         0.5f, -0.5f,  0.5f,  1.0f, 0.0f,           0.0f, -1.0f,  0.0f,
        -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,           0.0f, -1.0f,  0.0f,
        -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,           0.0f, -1.0f,  0.0f,

        -0.5f,  0.5f, -0.5f,  0.0f, 1.0f,           0.0f,  1.0f,  0.0f,
         0.5f,  0.5f, -0.5f,  1.0f, 1.0f,           0.0f,  1.0f,  0.0f,
         0.5f,  0.5f,  0.5f,  1.0f, 0.0f,           0.0f,  1.0f,  0.0f,
         0.5f,  0.5f,  0.5f,  1.0f, 0.0f,           0.0f,  1.0f,  0.0f,
        -0.5f,  0.5f,  0.5f,  0.0f, 0.0f,           0.0f,  1.0f,  0.0f,
        -0.5f,  0.5f, -0.5f,  0.0f, 1.0f,           0.0f,  1.0f,  0.0f,
    }; 


    glGenVertexArrays(1, &_VAO);
    glBindVertexArray(_VAO);

    glGenBuffers(1, &_VBO);
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(sizeof(float) * 3));
    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(sizeof(float) * 5));

    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glEnableVertexAttribArray(2);

    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    return _VAO;
}

uint createTexture(const char* _fileName)
{
    _pImage = ffImage::readFromFile(_fileName);
    uint _texture = 0;
    glGenTextures(1, &_texture);
    glBindTexture(GL_TEXTURE_2D, _texture);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _pImage->getWidth(), _pImage->getHeight(), 0, GL_RGBA, GL_UNSIGNED_BYTE, _pImage->getData());
    
    return _texture;
}
    
void initShader(const char* _vertexPath, const char* _fragPath)
{
    _shader_sun.initShader("shader/vsunShader.glsl", "shader/fsunShader.glsl");
    _shader_scene.initShader("shader/sceneShaderv.glsl", "shader/sceneShaderf.glsl");
    _shader_color.initShader("shader/colorShaderv.glsl", "shader/colorShaderf.glsl");
}

void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    glViewport(0, 0, width, height);
}

void processInput(GLFWwindow* window)
{
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);

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

void mouse_callback(GLFWwindow* window, double xpos, double ypos)
{
    _camera.onMouseMove(xpos, ypos);
}


int main()
{
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_COMPAT_PROFILE);

    GLFWwindow* window = glfwCreateWindow(800, 600, "OpenGL Core", NULL, NULL);
    if (window == NULL)
    {
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }

    glViewport(0, 0, _width, _height);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);


    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    glfwSetCursorPosCallback(window, mouse_callback);



    _camera.lookAt(glm::vec3(0.0f, 0.0f, 3.0f), glm::vec3(0.0f, 0.0f, -1.0f), glm::vec3(0.0f, 1.0f, 0.0f));
    _camera.setSpeed(0.01f);

    VAO_cube = createModel();
    VAO_sun = createModel();
    light_pos = glm::vec3(2.0f, 0.0f, 0.0f);
    light_color = glm::vec3(1.0f, 1.0f, 1.0f);

    _textureBox = createTexture("res/box.png");
    _textureSpec = createTexture("res/specular.png");
    initShader("shader/vertexShader.glsl", "shader/fragmentShader.glsl");

    while (!glfwWindowShouldClose(window))
    {
        processInput(window);
        rend();

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    glfwTerminate();
    return 0;
}