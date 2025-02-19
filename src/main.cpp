#define WORKGROUP_SIZE 256

// clang-format off
#include <glad/glad.h>
#include <GLFW/glfw3.h>
// clang-format on

#include <array>
#include <cmath>
#include <iostream>
#include <numeric>
#include <random>
#include <vector>

#include "Camera.hpp"
#include "ComputeShader.hpp"
#include "Fluid.hpp"
#include "Model.hpp"
#include "RenderShader.hpp"
#include "Texture.hpp"

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

  // // make particleShader
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
  RenderShader particleShader;
  RenderShader tankShader;
  try {
    particleShader.build(
      "./assets/shaders/particle.vert.glsl", "./assets/shaders/particle.frag.glsl"
    );
    tankShader.build("./assets/shaders/tank.vert.glsl", "./assets/shaders/tank.frag.glsl");
  } catch (const std::exception& err) {
    std::cerr << err.what();
    return 1;
  }

  // TODO: wrap everything in the try-catch
  ComputeShader simulation;
  try {
    simulation.build("./assets/shaders/simulation-step.comp.glsl");
  } catch (const std::exception& err) {
    std::cerr << err.what();
    return 1;
  }

  Model particle{"./assets/models/particle.obj", NormalType::__VERT_NORMAL};
  Texture densityGradient{"./assets/textures/density-gradient.png"};
  densityGradient.use(0);

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
  const int fluidY = 16;
  const int fluidZ = 16;
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

  // hashes
  const unsigned int mHash = 1024;
  std::array<unsigned int, mHash> hashes;
  hashes.fill(mHash);

  unsigned int hashesSSBO;
  glGenBuffers(1, &hashesSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, hashesSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int) * hashes.size(), hashes.data(), GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, hashesSSBO);

  // param
  float smoothingRadius = 0.5f;
  float lookAhead = 1.0f / 144.0f;

  // box
  float tankLength = 5.0f;
  float tankWidth = 2.5f;
  float tankHeight = 2.5f;
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

  // DEMO PARALLEL
  ComputeShader sort1, sort2, sort3, sort4, sort5;
  try {
    sort1.build("./assets/shaders/radix-sort-1.comp.glsl");
    sort2.build("./assets/shaders/radix-sort-2.comp.glsl");
    sort3.build("./assets/shaders/radix-sort-3.comp.glsl");
    sort4.build("./assets/shaders/radix-sort-4.comp.glsl");
    sort5.build("./assets/shaders/radix-sort-5.comp.glsl");
  } catch (const std::exception& err) {
    std::cerr << err.what();
    return 1;
  }

  const unsigned int sort_n = 1024;
  std::array<unsigned int, sort_n> input;
  std::array<unsigned int, sort_n> output;
  std::array<unsigned int, sort_n> hist;
  std::array<unsigned int, sort_n / WORKGROUP_SIZE> lastHist;
  std::array<unsigned int, sort_n> log;

  std::iota(input.begin(), input.end(), 0);
  std::random_device rd;
  std::mt19937 gen(rd());
  std::shuffle(input.begin(), input.end(), gen);

  for (int i = 0; i < 1024; i++) {
    std::cout << input[i] << " ";
  }

  output.fill(0);
  hist.fill(0);
  lastHist.fill(0);
  log.fill(0);

  unsigned int inputSSBO;
  glGenBuffers(1, &inputSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, inputSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int) * input.size(), input.data(), GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, inputSSBO);

  unsigned int outputSSBO;
  glGenBuffers(1, &outputSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, outputSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int) * output.size(), output.data(), GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, outputSSBO);

  unsigned int histSSBO;
  glGenBuffers(1, &histSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, histSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int) * hist.size(), hist.data(), GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 4, histSSBO);

  unsigned int lastHistSSBO;
  glGenBuffers(1, &lastHistSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, lastHistSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER,
    sizeof(unsigned int) * lastHist.size(),
    lastHist.data(),
    GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 5, lastHistSSBO);

  unsigned int logSSBO;
  glGenBuffers(1, &logSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, logSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int) * log.size(), log.data(), GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 6, logSSBO);
  // DEMO PARALLEL

  float deltaTime = 1.0f / 144.0f;
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

      simulation.use();
      simulation.uniform("deltaTime", deltaTime);
      simulation.uniform("nParticles", nParticles);
      simulation.uniform("smoothingRadius", smoothingRadius);
      simulation.uniform("lookAhead", lookAhead);
      simulation.uniform("tankLength", tankLength);
      simulation.uniform("tankHeight", tankHeight);
      simulation.uniform("tankWidth", tankWidth);
      simulation.uniform("time", currTime);
      glDispatchCompute((unsigned int)nParticles / 128, 1, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      accumulatedTime -= deltaTime;
    }

    // TODO: remove
    // 8-bit per pass → 4 passes for 32-bit keys
    // it's important that pass is an unsigned int
    for (unsigned int pass = 0; pass < 4; pass++) {
      sort1.use();
      sort1.uniform("pass", pass);
      glDispatchCompute((unsigned int)sort_n / WORKGROUP_SIZE, 1, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      sort2.use();
      glDispatchCompute((unsigned int)sort_n / WORKGROUP_SIZE, 1, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      sort3.use();
      glDispatchCompute((unsigned int)1, 1, 1);  // ? better way to handle
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      sort4.use();
      sort4.uniform("pass", pass);
      glDispatchCompute((unsigned int)sort_n / WORKGROUP_SIZE, 1, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      sort5.use();
      glDispatchCompute((unsigned int)sort_n / WORKGROUP_SIZE, 1, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    }

    glClearColor(0.6f, 0.88f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // // use compute particleShader
    // computeShader.use();
    // computeShader.uniform("camera.origin", origin);
    // computeShader.uniform("camera.u", u);
    // computeShader.uniform("camera.v", v);
    // computeShader.uniform("camera.w", w);
    // computeShader.uniform("camera.fovy", fovy);
    // glDispatchCompute((unsigned int)width, (unsigned int)height, 1);

    // // make sure writing to image has finished before read
    // glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

    particleShader.use();
    particleShader.uniform("view", state.camera.view());
    particleShader.uniform("projection", state.camera.projection());
    particleShader.uniform("nParticles", nParticles);
    particleShader.uniform("smoothingRadius", smoothingRadius);

    particle.draw(nParticles);
    // glBindVertexArray(particleVAO);
    // glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, nParticles);
    // glBindVertexArray(0);

    tankShader.use();
    tankShader.uniform("model", glm::mat4(1.0));
    tankShader.uniform("view", state.camera.view());
    tankShader.uniform("projection", state.camera.projection());

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
