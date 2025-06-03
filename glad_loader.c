#include "glad/glad.h"
#include <windows.h>
#include <stdio.h>

// Function pointers
void (APIENTRY *glClear)(GLbitfield mask);
void (APIENTRY *glClearColor)(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
void (APIENTRY *glEnable)(GLenum cap);
void (APIENTRY *glViewport)(GLint x, GLint y, GLsizei width, GLsizei height);

void (APIENTRY *glGenBuffers)(GLsizei n, GLuint *buffers);
void (APIENTRY *glBindBuffer)(GLenum target, GLuint buffer);
void (APIENTRY *glBufferData)(GLenum target, GLsizei size, const void *data, GLenum usage);

void (APIENTRY *glGenVertexArrays)(GLsizei n, GLuint *arrays);
void (APIENTRY *glBindVertexArray)(GLuint array);
void (APIENTRY *glVertexAttribPointer)(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);
void (APIENTRY *glEnableVertexAttribArray)(GLuint index);

void (APIENTRY *glDrawArrays)(GLenum mode, GLint first, GLsizei count);

void (APIENTRY *glGenTextures)(GLsizei n, GLuint *textures);
void (APIENTRY *glBindTexture)(GLenum target, GLuint texture);
void (APIENTRY *glTexImage2D)(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels);
void (APIENTRY *glTexParameteri)(GLenum target, GLenum pname, GLint param);
void (APIENTRY *glActiveTexture)(GLenum texture);

GLuint (APIENTRY *glCreateShader)(GLenum type);
void (APIENTRY *glShaderSource)(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length);
void (APIENTRY *glCompileShader)(GLuint shader);
void (APIENTRY *glGetShaderiv)(GLuint shader, GLenum pname, GLint *params);
void (APIENTRY *glGetShaderInfoLog)(GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
void (APIENTRY *glDeleteShader)(GLuint shader);

GLuint (APIENTRY *glCreateProgram)(void);
void (APIENTRY *glAttachShader)(GLuint program, GLuint shader);
void (APIENTRY *glLinkProgram)(GLuint program);
void (APIENTRY *glGetProgramiv)(GLuint program, GLenum pname, GLint *params);
void (APIENTRY *glGetProgramInfoLog)(GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
void (APIENTRY *glUseProgram)(GLuint program);

GLint (APIENTRY *glGetUniformLocation)(GLuint program, const GLchar *name);
void (APIENTRY *glUniformMatrix4fv)(GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
void (APIENTRY *glUniform1i)(GLint location, GLint v0);
void (APIENTRY *glUniform1f)(GLint location, GLfloat v0);
void (APIENTRY *glUniform3f)(GLint location, GLfloat v0, GLfloat v1, GLfloat v2);
void (APIENTRY *glUniform3fv)(GLint location, GLsizei count, const GLfloat *value);

// Version struct
struct gladGLversionStruct GLVersion = { 3, 3 };

// Simple loader using GetProcAddress
static void* get_proc_address(const char* name) {
    static HMODULE opengl32 = NULL;
    if (!opengl32) {
        opengl32 = LoadLibraryA("opengl32.dll");
        if (!opengl32) return NULL;
    }
    
    void* proc = GetProcAddress(opengl32, name);
    if (!proc) {
        // Try to get it via wglGetProcAddress
        typedef void* (WINAPI *PFNWGLGETPROCADDRESSPROC)(const char*);
        static PFNWGLGETPROCADDRESSPROC wglGetProcAddress = NULL;
        if (!wglGetProcAddress) {
            wglGetProcAddress = (PFNWGLGETPROCADDRESSPROC)GetProcAddress(opengl32, "wglGetProcAddress");
        }
        if (wglGetProcAddress) {
            proc = wglGetProcAddress(name);
        }
    }
    return proc;
}

int gladLoadGL(void) {
    // Load basic OpenGL functions
    glClear = (void (APIENTRY *)(GLbitfield))get_proc_address("glClear");
    glClearColor = (void (APIENTRY *)(GLfloat, GLfloat, GLfloat, GLfloat))get_proc_address("glClearColor");
    glEnable = (void (APIENTRY *)(GLenum))get_proc_address("glEnable");
    glViewport = (void (APIENTRY *)(GLint, GLint, GLsizei, GLsizei))get_proc_address("glViewport");
    
    // Load buffer functions
    glGenBuffers = (void (APIENTRY *)(GLsizei, GLuint *))get_proc_address("glGenBuffers");
    glBindBuffer = (void (APIENTRY *)(GLenum, GLuint))get_proc_address("glBindBuffer");
    glBufferData = (void (APIENTRY *)(GLenum, GLsizei, const void *, GLenum))get_proc_address("glBufferData");
    
    // Load vertex array functions
    glGenVertexArrays = (void (APIENTRY *)(GLsizei, GLuint *))get_proc_address("glGenVertexArrays");
    glBindVertexArray = (void (APIENTRY *)(GLuint))get_proc_address("glBindVertexArray");
    glVertexAttribPointer = (void (APIENTRY *)(GLuint, GLint, GLenum, GLboolean, GLsizei, const void *))get_proc_address("glVertexAttribPointer");
    glEnableVertexAttribArray = (void (APIENTRY *)(GLuint))get_proc_address("glEnableVertexAttribArray");
    
    // Load drawing functions
    glDrawArrays = (void (APIENTRY *)(GLenum, GLint, GLsizei))get_proc_address("glDrawArrays");
    
    // Load texture functions
    glGenTextures = (void (APIENTRY *)(GLsizei, GLuint *))get_proc_address("glGenTextures");
    glBindTexture = (void (APIENTRY *)(GLenum, GLuint))get_proc_address("glBindTexture");
    glTexImage2D = (void (APIENTRY *)(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *))get_proc_address("glTexImage2D");
    glTexParameteri = (void (APIENTRY *)(GLenum, GLenum, GLint))get_proc_address("glTexParameteri");
    glActiveTexture = (void (APIENTRY *)(GLenum))get_proc_address("glActiveTexture");
    
    // Load shader functions
    glCreateShader = (GLuint (APIENTRY *)(GLenum))get_proc_address("glCreateShader");
    glShaderSource = (void (APIENTRY *)(GLuint, GLsizei, const GLchar *const*, const GLint *))get_proc_address("glShaderSource");
    glCompileShader = (void (APIENTRY *)(GLuint))get_proc_address("glCompileShader");
    glGetShaderiv = (void (APIENTRY *)(GLuint, GLenum, GLint *))get_proc_address("glGetShaderiv");
    glGetShaderInfoLog = (void (APIENTRY *)(GLuint, GLsizei, GLsizei *, GLchar *))get_proc_address("glGetShaderInfoLog");
    glDeleteShader = (void (APIENTRY *)(GLuint))get_proc_address("glDeleteShader");
    
    // Load program functions
    glCreateProgram = (GLuint (APIENTRY *)(void))get_proc_address("glCreateProgram");
    glAttachShader = (void (APIENTRY *)(GLuint, GLuint))get_proc_address("glAttachShader");
    glLinkProgram = (void (APIENTRY *)(GLuint))get_proc_address("glLinkProgram");
    glGetProgramiv = (void (APIENTRY *)(GLuint, GLenum, GLint *))get_proc_address("glGetProgramiv");
    glGetProgramInfoLog = (void (APIENTRY *)(GLuint, GLsizei, GLsizei *, GLchar *))get_proc_address("glGetProgramInfoLog");
    glUseProgram = (void (APIENTRY *)(GLuint))get_proc_address("glUseProgram");
    
    // Load uniform functions
    glGetUniformLocation = (GLint (APIENTRY *)(GLuint, const GLchar *))get_proc_address("glGetUniformLocation");
    glUniformMatrix4fv = (void (APIENTRY *)(GLint, GLsizei, GLboolean, const GLfloat *))get_proc_address("glUniformMatrix4fv");
    glUniform1i = (void (APIENTRY *)(GLint, GLint))get_proc_address("glUniform1i");
    glUniform1f = (void (APIENTRY *)(GLint, GLfloat))get_proc_address("glUniform1f");
    glUniform3f = (void (APIENTRY *)(GLint, GLfloat, GLfloat, GLfloat))get_proc_address("glUniform3f");
    glUniform3fv = (void (APIENTRY *)(GLint, GLsizei, const GLfloat *))get_proc_address("glUniform3fv");
    
    // Return success if basic functions are loaded
    return (glClear && glClearColor && glEnable && glViewport) ? 1 : 0;
}

int gladLoadGLLoader(GLADloadproc load) {
    // For compatibility, but we're using our own loader
    return gladLoadGL();
} 