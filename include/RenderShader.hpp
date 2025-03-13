#pragma once

#include <glad/glad.h>

#include <glm/glm.hpp>
#include <string>

class RenderShader {
 public:
  RenderShader();
  RenderShader(const std::string& vertShaderPath, const std::string& fragShaderPath);
  ~RenderShader();

  void build(const std::string& vertShaderPath, const std::string& fragShaderPath);

  void use();
  void uniform(const std::string& uniformId, bool uniform) const;
  void uniform(const std::string& uniformId, int uniform) const;
  void uniform(const std::string& uniformId, unsigned int uniform) const;
  void uniform(const std::string& uniformId, float uniform) const;
  void uniform(const std::string& uniformId, glm::vec2 uniform) const;
  void uniform(const std::string& uniformId, glm::vec3 uniform) const;
  void uniform(const std::string& uniformId, glm::vec4 uniform) const;
  void uniform(const std::string& uniformId, glm::mat4 uniform) const;

 private:
  GLuint programId;

  GLuint compile(GLenum shaderType, const std::string& shaderPath);
  void link(GLuint vertShaderId, GLuint fragShaderId);
};
