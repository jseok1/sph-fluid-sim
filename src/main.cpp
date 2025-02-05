// clang-format off
#include "glad/glad.h"
#include <GLFW/glfw3.h>
// clang-format on

#include <iostream>

#include "Camera.hpp"
#include "ComputeShader.hpp"
#include "Fluid.hpp"
#include "Model.hpp"
#include "RenderShader.hpp"

const float fovy = 45.0f;
int width = 1920;  // bad being overwritten
int height = 1080;
const float near = 0.01f;
const float far = 100.0f;
const bool throttle = true;

const float speed = 5.0f;
const float sensitivity = 0.05f;

struct State {
  bool isMovingForward = false;
  bool isMovingBackward = false;
  bool isMovingLeftward = false;
  bool isMovingRightward = false;
  bool isMovingUpward = false;
  bool isMovingDownward = false;

  Camera camera = Camera(fovy, width, height, near, far);
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

  glm::vec2 delta = glm::vec2(-(currYCoord - prevYCoord), currXCoord - prevXCoord) * sensitivity;

  state.camera.rotateBy(delta);

  prevXCoord = currXCoord;
  prevYCoord = currYCoord;
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

  GLFWmonitor* monitor = glfwGetPrimaryMonitor();
  const GLFWvidmode* mode = glfwGetVideoMode(monitor);
  width = mode->width;
  height = mode->height;
  GLFWwindow* window = glfwCreateWindow(width, height, "🌊🌊🌊", monitor, nullptr);
  if (!window) {
    return 1;
  }
  glfwMakeContextCurrent(window);

  glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
  glfwSetFramebufferSizeCallback(window, processFrameBufferState);
  glfwSetCursorPosCallback(window, processMouse);
  glfwSetKeyCallback(window, processKey);

  if (!throttle) {
    glfwSwapInterval(0);
  }

  if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
    return 1;
  }

  glEnable(GL_DEPTH_TEST);
  glEnable(GL_MULTISAMPLE);
  glEnable(GL_CULL_FACE);

  state.camera = Camera(fovy, width, height, near, far);  // bad
  state.camera.translateTo(glm::vec3(0.0, 0.0, 10.0));
  state.camera.rotateTo(glm::vec2(0.0, -90.0));

  // // make texture
  // unsigned int texture;

  // glGenTextures(1, &texture);
  // glActiveTexture(GL_TEXTURE0);
  // glBindTexture(GL_TEXTURE_2D, texture);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  // glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, NULL);

  // glBindImageTexture(0, texture, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA32F);

  // // make shader
  // ComputeShader computeShader{"./assets/shaders/screen.comp"};
  // RenderShader renderShader{
  //   "./assets/shaders/screen.vert", "./assets/shaders/screen.frag"
  // };
  // renderShader.use();
  // renderShader.uniform("tex", 0);

  // // make quad
  // unsigned int quadVAO = 0;
  // unsigned int quadVBO;
  // float quadVertices[] = {
  //   // clang-format off
  //   -1.0f,  1.0f, 0.0f, 0.0f, 1.0f,
  //   -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,
  //    1.0f,  1.0f, 0.0f, 1.0f, 1.0f,
  //    1.0f, -1.0f, 0.0f, 1.0f, 0.0f,
  //   // clang-format on
  // };
  // // setup plane VAO
  // glGenVertexArrays(1, &quadVAO);
  // glGenBuffers(1, &quadVBO);
  // glBindVertexArray(quadVAO);
  // glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
  // glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), &quadVertices, GL_STATIC_DRAW);
  // glEnableVertexAttribArray(0);
  // glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
  // glEnableVertexAttribArray(1);
  // glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));

  RenderShader shader{"./assets/shaders/particle.vert.glsl", "./assets/shaders/particle.frag.glsl"};
  RenderShader tank{"./assets/shaders/tank.vert.glsl", "./assets/shaders/tank.frag.glsl"};

  // TODO: wrap everything in the try-catch
  ComputeShader simulation1;
  ComputeShader simulation2;
  try {
    simulation1.build("./assets/shaders/simulation-step-pre.comp.glsl");
    simulation2.build("./assets/shaders/simulation-step.comp.glsl");
  } catch (const std::exception& err) {
    std::cerr << err.what();
    return 1;
  }

  Model particle{"./assets/models/particle.obj", NormalType::__VERT_NORMAL};

  // unsigned int particleVAO;
  // unsigned int particleVBO;
  // float particleVertices[] = {
  //   // clang-format off
  //   -0.1f,  0.1f, 0.0f,
  //   -0.1f, -0.1f, 0.0f,
  //    0.1f,  0.1f, 0.0f,
  //    0.1f, -0.1f, 0.0f,
  //   // clang-format on
  // };
  // glGenVertexArrays(1, &particleVAO);
  // glGenBuffers(1, &particleVBO);
  // glBindVertexArray(particleVAO);
  // glBindBuffer(GL_ARRAY_BUFFER, particleVBO);
  // glBufferData(GL_ARRAY_BUFFER, sizeof(particleVertices), particleVertices, GL_DYNAMIC_DRAW);
  // glEnableVertexAttribArray(0);
  // glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
  // glBindVertexArray(0);

  // particles (dims should be a multiple of two)
  const int fluidX = 16;
  const int fluidY = 8;
  const int fluidZ = 8;
  const int nParticles = fluidX * fluidY * fluidZ;
  Fluid fluid(fluidX, fluidY, fluidZ);

  unsigned int particlesSSBO;
  glGenBuffers(1, &particlesSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, particlesSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER,
    sizeof(Particle) * fluid.particles.size(),
    fluid.particles.data(),
    GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, particlesSSBO);

  // param
  float smoothingRadius = 5.0f;

  // box
  float tankLength = 5.0;
  float tankWidth = 2.5;
  float tankHeight = 2.5;
  unsigned int boxVAO;
  unsigned int boxVBO;
  unsigned int boxEBO;
  float boxVertices[] = {
    // clang-format off
     tankLength, -tankHeight, -tankWidth,
     tankLength, -tankHeight,  tankWidth,
    -tankLength, -tankHeight,  tankWidth,
    -tankLength, -tankHeight, -tankWidth,
     tankLength,  tankHeight, -tankWidth,
     tankLength,  tankHeight,  tankWidth,
    -tankLength,  tankHeight,  tankWidth,
    -tankLength,  tankHeight, -tankWidth
    // clang-format on
  };
  unsigned int boxIndices[] = {
    // clang-format off
    1, 2, 3,
    7, 6, 5,
    4, 5, 1,
    5, 6, 2,
    2, 6, 7,
    0, 3, 7,
    0, 1, 3,
    4, 7, 5,
    0, 4, 1,
    1, 5, 2,
    3, 2, 7,
    4, 0, 7,
    // clang-format on
  };
  glGenVertexArrays(1, &boxVAO);
  glGenBuffers(1, &boxVBO);
  glGenBuffers(1, &boxEBO);

  glBindVertexArray(boxVAO);

  glBindBuffer(GL_ARRAY_BUFFER, boxVBO);
  glBufferData(GL_ARRAY_BUFFER, sizeof(boxVertices), boxVertices, GL_STATIC_DRAW);

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, boxEBO);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(boxIndices), boxIndices, GL_STATIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);

  glBindVertexArray(0);

  float deltaTime = 1.0f / 60.0f;
  float prevTime = glfwGetTime();
  float accumulatedTime = 0.0f;

  while (!glfwWindowShouldClose(window)) {
    auto origin = state.camera.origin();
    auto [u, v, w] = state.camera.basis();

    float currTime = glfwGetTime();
    accumulatedTime += currTime - prevTime;
    prevTime = currTime;

    while (accumulatedTime >= deltaTime) {
      glm::vec3 delta = glm::vec3(0.0);
      if (state.isMovingForward) delta -= w * speed * deltaTime;
      if (state.isMovingBackward) delta += w * speed * deltaTime;
      if (state.isMovingLeftward) delta -= u * speed * deltaTime;
      if (state.isMovingRightward) delta += u * speed * deltaTime;
      if (state.isMovingDownward) delta -= v * speed * deltaTime;
      if (state.isMovingUpward) delta += v * speed * deltaTime;
      state.camera.translateBy(delta);

      simulation1.use();
      simulation1.uniform("deltaTime", deltaTime);
      simulation1.uniform("nParticles", nParticles);
      simulation1.uniform("smoothingRadius", smoothingRadius);
      glDispatchCompute((unsigned int)nParticles / 128, 1, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      simulation2.use();
      simulation2.uniform("deltaTime", deltaTime);
      simulation2.uniform("nParticles", nParticles);
      simulation2.uniform("smoothingRadius", smoothingRadius);
      simulation2.uniform("tankLength", tankLength);
      simulation2.uniform("tankHeight", tankHeight);
      simulation2.uniform("tankWidth", tankWidth);
      glDispatchCompute((unsigned int)nParticles / 128, 1, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      accumulatedTime -= deltaTime;
    }

    glClearColor(0.6f, 0.88f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // // use compute shader
    // computeShader.use();
    // computeShader.uniform("camera.origin", origin);
    // computeShader.uniform("camera.u", u);
    // computeShader.uniform("camera.v", v);
    // computeShader.uniform("camera.w", w);
    // computeShader.uniform("camera.fovy", fovy);
    // glDispatchCompute((unsigned int)width, (unsigned int)height, 1);

    // // make sure writing to image has finished before read
    // glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

    shader.use();
    shader.uniform("view", state.camera.view());
    shader.uniform("projection", state.camera.projection());

    particle.draw(nParticles);
    // glBindVertexArray(particleVAO);
    // glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, nParticles);
    // glBindVertexArray(0);

    tank.use();
    tank.uniform("model", glm::mat4(1.0));
    tank.uniform("view", state.camera.view());
    tank.uniform("projection", state.camera.projection());

    glBindVertexArray(boxVAO);
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    glDrawElements(GL_TRIANGLES, 48, GL_UNSIGNED_INT, 0);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    glBindVertexArray(0);

    glfwSwapBuffers(window);
    glfwPollEvents();
  }

  glfwTerminate();
  return 0;
}
