// clang-format off
#include "glad/glad.h"
#include <GLFW/glfw3.h>
// clang-format on

#include <iostream>

#include "Camera.hpp"
#include "ComputeShader.hpp"
#include "RenderShader.hpp"

struct State {
  bool isMovingForward = false;
  bool isMovingBackward = false;
  bool isMovingLeftward = false;
  bool isMovingRightward = false;
  bool isMovingUpward = false;
  bool isMovingDownward = false;

  Camera camera = Camera(45.0);
} state;

bool firstMouse = true;
double prevXCoord, prevYCoord;

void processFrameBufferState(GLFWwindow* window, int width, int height) {
  glViewport(0, 0, width, height);
}

void processMouse(GLFWwindow* window, double currXCoord, double currYCoord) {
  if (firstMouse) {
    prevXCoord = currXCoord;
    prevYCoord = currYCoord;
    firstMouse = false;
  }

  double xOffset = currXCoord - prevXCoord;
  double yOffset = -(currYCoord - prevYCoord);
  prevXCoord = currXCoord;
  prevYCoord = currYCoord;

  const float sensitivity = 0.05f;
  xOffset *= sensitivity;
  yOffset *= sensitivity;

  state.camera.rotate(xOffset, yOffset);
}

void processKey(GLFWwindow* window, int key, int scancode, int action, int mods) {
  if (action == GLFW_PRESS) {
    if (key == GLFW_KEY_ESCAPE) {
      glfwSetWindowShouldClose(window, GL_TRUE);
      return;
    }

    if (key == GLFW_KEY_W) {
      state.isMovingForward = true;
      return;
    }
    if (key == GLFW_KEY_S) {
      state.isMovingBackward = true;
      return;
    }
    if (key == GLFW_KEY_D) {
      state.isMovingRightward = true;
      return;
    }
    if (key == GLFW_KEY_A) {
      state.isMovingLeftward = true;
      return;
    }
    if (key == GLFW_KEY_SPACE) {
      state.isMovingUpward = true;
      return;
    }
    if (key == GLFW_KEY_LEFT_SHIFT) {
      state.isMovingDownward = true;
      return;
    }
  }

  if (action == GLFW_RELEASE) {
    if (key == GLFW_KEY_W) {
      state.isMovingForward = false;
      return;
    }
    if (key == GLFW_KEY_S) {
      state.isMovingBackward = false;
      return;
    }
    if (key == GLFW_KEY_D) {
      state.isMovingRightward = false;
      return;
    }
    if (key == GLFW_KEY_A) {
      state.isMovingLeftward = false;
      return;
    }
    if (key == GLFW_KEY_SPACE) {
      state.isMovingUpward = false;
      return;
    }
    if (key == GLFW_KEY_LEFT_SHIFT) {
      state.isMovingDownward = false;
      return;
    }
  }
}

int main() {
  glfwInit();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

#ifdef __APPLE__
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif
  const int width = 1920;
  const int height = 1080;

  GLFWwindow* window = glfwCreateWindow(width, height, "Sphere Tracing", nullptr, nullptr);
  if (!window) {
    return 1;
  }
  glfwMakeContextCurrent(window);

  glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
  glfwSetFramebufferSizeCallback(window, processFrameBufferState);
  glfwSetCursorPosCallback(window, processMouse);
  glfwSetKeyCallback(window, processKey);

  // glfwSwapInterval(0);  // disable frame limiting

  if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
    return 1;
  }

  // make texture
  const unsigned int TEXTURE_WIDTH = width, TEXTURE_HEIGHT = height;  // ? this used to be 512 x 512
  unsigned int texture;

  glGenTextures(1, &texture);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, texture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexImage2D(
    GL_TEXTURE_2D, 0, GL_RGBA32F, TEXTURE_WIDTH, TEXTURE_HEIGHT, 0, GL_RGBA, GL_FLOAT, NULL
  );

  glBindImageTexture(0, texture, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA32F);

  // make shader
  ComputeShader computeShader{"./res/shaders/compute.glsl"};
  RenderShader renderShader{"./res/shaders/vert.glsl", "./res/shaders/frag.glsl"};
  renderShader.use();
  renderShader.uniform("tex", 0);

  // make quad
  unsigned int quadVAO = 0;
  unsigned int quadVBO;
  float quadVertices[] = {
    // clang-format off
    -1.0f,  1.0f, 0.0f, 0.0f, 1.0f,
    -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,
     1.0f,  1.0f, 0.0f, 1.0f, 1.0f,
     1.0f, -1.0f, 0.0f, 1.0f, 0.0f,
    // clang-format on
  };
  // setup plane VAO
  glGenVertexArrays(1, &quadVAO);
  glGenBuffers(1, &quadVBO);
  glBindVertexArray(quadVAO);
  glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
  glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), &quadVertices, GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));

  double deltaTime = 0.01666666666;
  double prevTime = glfwGetTime();
  double accumulatedTime = 0.0;

  int frameCount = 0;

  const float speed = 5.0f * deltaTime;

  while (!glfwWindowShouldClose(window)) {
    double currTime = glfwGetTime();
    accumulatedTime += currTime - prevTime;
    prevTime = currTime;

    if (frameCount > 500) {
      // std::cout << "FPS: " << 1 / (currTime - prevTime) << std::endl;
      frameCount = 0;
    } else {
      frameCount++;
    }

    while (accumulatedTime >= deltaTime) {
      glm::vec3 deltaOrigin{0.0, 0.0, 0.0};
      if (state.isMovingForward) deltaOrigin -= state.camera.backward * speed;
      if (state.isMovingBackward) deltaOrigin += state.camera.backward * speed;
      if (state.isMovingLeftward) deltaOrigin -= state.camera.rightward * speed;
      if (state.isMovingRightward) deltaOrigin += state.camera.rightward * speed;
      if (state.isMovingDownward) deltaOrigin -= state.camera.upward * speed;
      if (state.isMovingUpward) deltaOrigin += state.camera.upward * speed;
      state.camera.translate(deltaOrigin);

      accumulatedTime -= deltaTime;
    }

    glClearColor(0.7f, 0.7f, 0.7f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
      glfwSetWindowShouldClose(window, GL_TRUE);

    // use compute shader
    computeShader.use();
    computeShader.uniform("camera.origin", state.camera.origin);
    computeShader.uniform("camera.rightward", state.camera.rightward);
    computeShader.uniform("camera.upward", state.camera.upward);
    computeShader.uniform("camera.backward", state.camera.backward);
    computeShader.uniform("camera.fov", state.camera.fov);
    glDispatchCompute((unsigned int)TEXTURE_WIDTH, (unsigned int)TEXTURE_HEIGHT, 1);

    // make sure writing to image has finished before read
    glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

    //
    renderShader.use();
    glBindVertexArray(quadVAO);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);

    glfwSwapBuffers(window);
    glfwPollEvents();
  }

  glfwTerminate();
  return 0;
}
