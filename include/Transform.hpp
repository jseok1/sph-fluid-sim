#pragma once

#include <glm/glm.hpp>

// food for thought about getters/setters:
// https://stackoverflow.com/questions/51615363/how-to-write-c-getters-and-setters#answer-51616894
class Transform {
 public:
  glm::vec3 translation;
  glm::vec3 rotation;
  glm::vec3 scale;

  Transform() : translation{glm::vec3(0.0f)}, rotation{glm::vec3(0.0f)}, scale{glm::vec3(1.0f)} {};

  void translateBy(glm::vec3 by) {
    translation += by;
  };

  void translateTo(glm::vec3 to) {
    translation = to;
  };

  void rotateBy(glm::vec3 by) {
    rotation += by;
    rotation = glm::mod(rotation + 180.0f, 360.0f) - 180.0f;
  };

  void rotateTo(glm::vec3 to) {
    rotation = glm::mod(to + 180.0f, 360.0f) - 180.0f;
  };

  void scaleBy(glm::vec3 by) {
    scale *= by;
  };

  void scaleTo(glm::vec3 to) {
    scale *= to;
  };

  glm::mat4 model() {
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::translate(model, translation);
    model = glm::rotate(model, glm::radians(rotation.x), glm::vec3(1.0f, 0.0f, 0.0f));
    model = glm::rotate(model, glm::radians(rotation.y), glm::vec3(0.0f, 1.0f, 0.0f));
    model = glm::rotate(model, glm::radians(rotation.z), glm::vec3(0.0f, 0.0f, 1.0f));
    model = glm::scale(model, scale);
    return model;
  }
};
