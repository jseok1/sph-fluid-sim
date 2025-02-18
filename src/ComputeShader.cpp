#include "ComputeShader.hpp"

#include <glad/glad.h>

#include <fstream>
#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

ComputeShader::ComputeShader() {}

ComputeShader::ComputeShader(const std::string& computeShaderPath) {
  GLuint computerShaderId = compile(GL_COMPUTE_SHADER, computeShaderPath);
  link(computerShaderId);
}

ComputeShader::~ComputeShader() {
  glDeleteProgram(programId);
}

void ComputeShader::build(const std::string& computeShaderPath) {
  GLuint computerShaderId = compile(GL_COMPUTE_SHADER, computeShaderPath);
  link(computerShaderId);
}

GLuint ComputeShader::compile(GLenum shaderType, const std::string& shaderPath) {
  // TODO: file IO error handling
  std::ifstream shaderFile;
  shaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);

  shaderFile.open(shaderPath);
  std::stringstream ComputeShader;
  ComputeShader << shaderFile.rdbuf();
  shaderFile.close();

  std::string shaderSourceCpp = ComputeShader.str();
  const char* shaderSource = shaderSourceCpp.c_str();

  GLuint shaderId = glCreateShader(shaderType);
  glShaderSource(shaderId, 1, &shaderSource, NULL);
  glCompileShader(shaderId);

  int compiled;
  glGetShaderiv(shaderId, GL_COMPILE_STATUS, &compiled);
  if (!compiled) {
    char log[512];
    glGetShaderInfoLog(shaderId, 512, NULL, log);
    throw std::runtime_error(
      "ERROR::ComputeShader::COMPILATION_FAILED at " + shaderPath + "\n" + std::string(log)
    );
  };

  return shaderId;
}

void ComputeShader::link(GLuint computerShaderId) {
  programId = glCreateProgram();
  glAttachShader(programId, computerShaderId);
  glLinkProgram(programId);

  int isLinked;
  glGetProgramiv(programId, GL_LINK_STATUS, &isLinked);
  if (!isLinked) {
    char log[512];
    glGetProgramInfoLog(programId, 512, NULL, log);
    throw std::runtime_error("ERROR::ComputeShader::PROGRAM::LINKING_FAILED\n" + std::string(log));
  }

  glDeleteShader(computerShaderId);
}

void ComputeShader::use() {
  glUseProgram(programId);
}

void ComputeShader::uniform(const std::string& uniformId, bool uniform) const {
  glUniform1i(glGetUniformLocation(programId, uniformId.c_str()), uniform ? GL_TRUE : GL_FALSE);
}

void ComputeShader::uniform(const std::string& uniformId, int uniform) const {
  GLint uniformLocation = glGetUniformLocation(programId, uniformId.c_str());
  // if (uniformLocation == -1) throw std::runtime_error("ComputeShader::UNIFORM:NOT_FOUND " +
  // uniformId);
  glUniform1i(uniformLocation, uniform);
}

void ComputeShader::uniform(const std::string& uniformId, unsigned int uniform) const {
  GLint uniformLocation = glGetUniformLocation(programId, uniformId.c_str());
  glUniform1ui(uniformLocation, uniform);
}

void ComputeShader::uniform(const std::string& uniformId, float uniform) const {
  glUniform1f(glGetUniformLocation(programId, uniformId.c_str()), uniform);
}

void ComputeShader::uniform(const std::string& uniformId, glm::vec2 uniform) const {
  glUniform2fv(glGetUniformLocation(programId, uniformId.c_str()), 1, glm::value_ptr(uniform));
}

void ComputeShader::uniform(const std::string& uniformId, glm::vec3 uniform) const {
  glUniform3fv(glGetUniformLocation(programId, uniformId.c_str()), 1, glm::value_ptr(uniform));
}

void ComputeShader::uniform(const std::string& uniformId, glm::vec4 uniform) const {
  glUniform4fv(glGetUniformLocation(programId, uniformId.c_str()), 1, glm::value_ptr(uniform));
}

void ComputeShader::uniform(const std::string& uniformId, glm::mat4 uniform) const {
  glUniformMatrix4fv(
    glGetUniformLocation(programId, uniformId.c_str()), 1, GL_FALSE, glm::value_ptr(uniform)
  );
}
