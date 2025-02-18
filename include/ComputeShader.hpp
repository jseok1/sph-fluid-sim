#pragma once

#include <glad/glad.h>

#include <glm/glm.hpp>
#include <string>

// could use overloading to combine with vert/frag
class ComputeShader {
 public:
  ComputeShader();
  ComputeShader(const std::string& computeShaderPath);
  ~ComputeShader();

  void build(const std::string& computeShaderPath);

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
  void link(GLuint computeShaderId);
};
