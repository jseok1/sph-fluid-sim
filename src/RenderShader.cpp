#include "RenderShader.hpp"

#include <glad/glad.h>

#include <fstream>
#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

// make GL_VERTEX_SHADER C++ enums?
RenderShader::RenderShader() {}

RenderShader::RenderShader(const std::string& vertShaderPath, const std::string& fragShaderPath) {
  GLuint vertShaderId = compile(GL_VERTEX_SHADER, vertShaderPath);
  GLuint fragShaderId = compile(GL_FRAGMENT_SHADER, fragShaderPath);
  link(vertShaderId, fragShaderId);
}

RenderShader::~RenderShader() {
  glDeleteProgram(programId);
}

void RenderShader::build(const std::string& vertShaderPath, const std::string& fragShaderPath) {
  GLuint vertShaderId = compile(GL_VERTEX_SHADER, vertShaderPath);
  GLuint fragShaderId = compile(GL_FRAGMENT_SHADER, fragShaderPath);
  link(vertShaderId, fragShaderId);
}

GLuint RenderShader::compile(GLenum shaderType, const std::string& shaderPath) {
  std::ifstream shaderFile;
  shaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);

  shaderFile.open(shaderPath);
  std::stringstream RenderShader;
  RenderShader << shaderFile.rdbuf();
  shaderFile.close();

  std::string shaderSourceCpp = RenderShader.str();
  const char* shaderSource = shaderSourceCpp.c_str();

  GLuint shaderId = glCreateShader(shaderType);
  glShaderSource(shaderId, 1, &shaderSource, NULL);
  glCompileShader(shaderId);

  int compiled;
  glGetShaderiv(shaderId, GL_COMPILE_STATUS, &compiled);
  if (!compiled) {
    char log[512];
    glGetShaderInfoLog(shaderId, 512, NULL, log);
    throw std::runtime_error("ERROR::RenderShader::COMPILATION_FAILED\n" + std::string(log));
  };

  return shaderId;
}

void RenderShader::link(GLuint vertShaderId, GLuint fragShaderId) {
  programId = glCreateProgram();
  glAttachShader(programId, vertShaderId);
  glAttachShader(programId, fragShaderId);
  glLinkProgram(programId);

  int isLinked;
  glGetProgramiv(programId, GL_LINK_STATUS, &isLinked);
  if (!isLinked) {
    char log[512];
    glGetProgramInfoLog(programId, 512, NULL, log);
    throw std::runtime_error("ERROR::RenderShader::PROGRAM::LINKING_FAILED\n" + std::string(log));
  }

  glDeleteShader(vertShaderId);
  glDeleteShader(fragShaderId);
}

void RenderShader::use() {
  glUseProgram(programId);
}

void RenderShader::uniform(const std::string& uniformId, bool uniform) const {
  glUniform1i(glGetUniformLocation(programId, uniformId.c_str()), uniform ? GL_TRUE : GL_FALSE);
}

void RenderShader::uniform(const std::string& uniformId, int uniform) const {
  GLint uniformLocation = glGetUniformLocation(programId, uniformId.c_str());
  // if (uniformLocation == -1) throw std::runtime_error("RenderShader::UNIFORM:NOT_FOUND " +
  // uniformId);
  glUniform1i(uniformLocation, uniform);
}

void RenderShader::uniform(const std::string& uniformId, unsigned int uniform) const {
  GLint uniformLocation = glGetUniformLocation(programId, uniformId.c_str());
  glUniform1ui(uniformLocation, uniform);
}

void RenderShader::uniform(const std::string& uniformId, float uniform) const {
  glUniform1f(glGetUniformLocation(programId, uniformId.c_str()), uniform);
}

void RenderShader::uniform(const std::string& uniformId, glm::vec2 uniform) const {
  glUniform2fv(glGetUniformLocation(programId, uniformId.c_str()), 1, glm::value_ptr(uniform));
}

void RenderShader::uniform(const std::string& uniformId, glm::vec3 uniform) const {
  glUniform3fv(glGetUniformLocation(programId, uniformId.c_str()), 1, glm::value_ptr(uniform));
}

void RenderShader::uniform(const std::string& uniformId, glm::vec4 uniform) const {
  glUniform4fv(glGetUniformLocation(programId, uniformId.c_str()), 1, glm::value_ptr(uniform));
}

void RenderShader::uniform(const std::string& uniformId, glm::mat4 uniform) const {
  glUniformMatrix4fv(
    glGetUniformLocation(programId, uniformId.c_str()), 1, GL_FALSE, glm::value_ptr(uniform)
  );
}
