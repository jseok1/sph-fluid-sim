#pragma once

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <tuple>

#include "Transform.hpp"

class Camera {
 public:
  Camera(float fovy, float width, float height, float near, float far)
    : transform{}, fovy{fovy}, width{width}, height{height}, near{near}, far{far} {};

  glm::vec3 origin() {
    return transform.translation;
  }

  std::tuple<glm::vec3, glm::vec3, glm::vec3> basis() {
    return std::make_tuple(u, v, w);
  }

  void translateBy(glm::vec3 by) {
    transform.translateBy(by);
  };

  void translateTo(glm::vec3 to) {
    transform.translateTo(to);
  };

  void rotateBy(glm::vec2 by) {
    by.x = glm::clamp(transform.rotation.x + by.x, -89.0f, 89.0f) - transform.rotation.x;

    transform.rotateBy(glm::vec3(by, 0.0));

    w = glm::vec3(
      -glm::cos(glm::radians(transform.rotation.y)) * glm::cos(glm::radians(transform.rotation.x)),
      -glm::sin(glm::radians(transform.rotation.x)),
      -glm::sin(glm::radians(transform.rotation.y)) * glm::cos(glm::radians(transform.rotation.x))
    );
    u = glm::cross(glm::vec3(0.0f, 1.0f, 0.0f), w);
    v = glm::cross(w, u);

    u = glm::normalize(u);
    v = glm::normalize(v);
    w = glm::normalize(w);
  };

  void rotateTo(glm::vec2 to) {
    to.x = glm::clamp(to.x, -89.0f, 89.0f);

    transform.rotateTo(glm::vec3(to, 0.0));

    w = glm::vec3(
      -glm::cos(glm::radians(transform.rotation.y)) * glm::cos(glm::radians(transform.rotation.x)),
      -glm::sin(glm::radians(transform.rotation.x)),
      -glm::sin(glm::radians(transform.rotation.y)) * glm::cos(glm::radians(transform.rotation.x))
    );
    u = glm::cross(glm::vec3(0.0f, 1.0f, 0.0f), w);
    v = glm::cross(w, u);

    u = glm::normalize(u);
    v = glm::normalize(v);
    w = glm::normalize(w);
  };

  glm::mat4 view() {
    glm::mat4 view = glm::lookAt(transform.translation, transform.translation - w, v);
    return view;
  }

  glm::mat4 projection() {
    glm::mat4 projection = glm::perspective(glm::radians(fovy), width / height, near, far);
    return projection;
  }

 private:
  Transform transform;
  glm::vec3 u, v, w;
  float fovy;
  float width;
  float height;
  float near;
  float far;
};
