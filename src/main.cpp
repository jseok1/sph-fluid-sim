#define RADIX 256
#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

// clang-format off
#include <glad/glad.h>
#include <GLFW/glfw3.h>
// clang-format on

#include <array>
#include <cassert>
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
const bool fullscreen = false;

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
  glfwWindowHint(GLFW_SAMPLES, 4);

#ifdef __APPLE__
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

  GLFWwindow* window;
  if (fullscreen) {
    GLFWmonitor* monitor = glfwGetPrimaryMonitor();
    const GLFWvidmode* mode = glfwGetVideoMode(monitor);
    width = mode->width;
    height = mode->height;
    window = glfwCreateWindow(width, height, "🌊🌊🌊", monitor, nullptr);
  } else {
    window = glfwCreateWindow(width, height, "🌊🌊🌊", nullptr, nullptr);
  }
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
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glEnable(GL_BLEND);

  state.camera = Camera(fovy, width, height, near, far);  // bad
  state.camera.translateTo(glm::vec3(0.0, 0.0, 10.0));
  state.camera.rotateTo(glm::vec2(0.0, -90.0));

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
  RenderShader particleShader, tankShader;
  ComputeShader sph1, sph2, radixSortCount, radixSortScan, radixSortScatter, radixSortSwap,
    hashIndicesClear, hashIndices;
  try {
    particleShader.build(
      "./assets/shaders/particle.vert.glsl", "./assets/shaders/particle.frag.glsl"
    );
    tankShader.build("./assets/shaders/tank.vert.glsl", "./assets/shaders/tank.frag.glsl");
    sph1.build("./assets/shaders/sph-1.comp.glsl");
    sph2.build("./assets/shaders/sph-2.comp.glsl");
    radixSortCount.build("./assets/shaders/radix-sort-1-count.comp.glsl");
    radixSortScan.build("./assets/shaders/radix-sort-2-scan.comp.glsl");
    radixSortScatter.build("./assets/shaders/radix-sort-3-scatter.comp.glsl");
    hashIndices.build("./assets/shaders/hash-indices.comp.glsl");
  } catch (const std::exception& err) {
    std::cerr << err.what();
    return 1;
  }

  // move all particle init to GPU

  // TODO: wrap everything in the try-catch

  Model particle{"./assets/models/particle.obj", NormalType::__VERT_NORMAL};
  Texture densityGradient{"./assets/textures/density-gradient.png"};
  densityGradient.use(0);

  // particles (dims should be a multiple of two)
  const int fluidX = 16;
  const int fluidY = 32;
  const int fluidZ = 16;
  const unsigned int nParticles = fluidX * fluidY * fluidZ;
  static_assert(nParticles % WORKGROUP_SIZE == 0);
  static_assert(WORKGROUP_SIZE >= RADIX);

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
  const unsigned int HASH_TABLE_SIZE = WORKGROUP_SIZE * 256;
  unsigned int hashIndicesSSBO;
  glGenBuffers(1, &hashIndicesSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, hashIndicesSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int) * HASH_TABLE_SIZE, nullptr, GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, hashIndicesSSBO);

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
  std::vector<ParticleHandle> front(nParticles);
  std::vector<ParticleHandle> back(nParticles);

  for (int i = 0; i < nParticles; i++) {
    front[i].index = i;
  }

  unsigned int frontSSBO;
  glGenBuffers(1, &frontSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, frontSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER, sizeof(ParticleHandle) * front.size(), front.data(), GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, frontSSBO);

  unsigned int backSSBO;
  glGenBuffers(1, &backSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, backSSBO);
  glBufferData(
    GL_SHADER_STORAGE_BUFFER, sizeof(ParticleHandle) * back.size(), back.data(), GL_DYNAMIC_DRAW
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, backSSBO);

  unsigned int total_n = 0;
  unsigned int curr_n = ceil(static_cast<float>(nParticles) / WORKGROUP_SIZE) * RADIX;
  while (curr_n > 1) {
    total_n += ceil(static_cast<float>(curr_n) / WORKGROUP_SIZE) * WORKGROUP_SIZE;
    curr_n /= WORKGROUP_SIZE;
  }

  unsigned int histogramSSBO;
  glGenBuffers(1, &histogramSSBO);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, histogramSSBO);
  glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int) * total_n, nullptr, GL_DYNAMIC_DRAW);
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 4, histogramSSBO);
  glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, nullptr);

  // unsigned int logSSBO;
  // glGenBuffers(1, &logSSBO);
  // glBindBuffer(GL_SHADER_STORAGE_BUFFER, logSSBO);
  // glBufferData(
  //   GL_SHADER_STORAGE_BUFFER, sizeof(unsigned int) * nParticles, nullptr, GL_DYNAMIC_DRAW
  // );
  // glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 5, logSSBO);
  // glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, nullptr);

  // DEMO PARALLEL

  int maxSSBOSize;
  glGetIntegerv(GL_MAX_SHADER_STORAGE_BLOCK_SIZE, &maxSSBOSize);
  printf("Max SSBO size: %d bytes\n", maxSSBOSize);

  int maxSSBOBindings;
  glGetIntegerv(GL_MAX_SHADER_STORAGE_BUFFER_BINDINGS, &maxSSBOBindings);
  printf("Max SSBO bindings: %d\n", maxSSBOBindings);

  int maxComputeSSBOs;
  glGetIntegerv(GL_MAX_COMPUTE_SHADER_STORAGE_BLOCKS, &maxComputeSSBOs);
  printf("Max SSBOs in compute shader: %d\n", maxComputeSSBOs);

  const float deltaTime = 1.0f / 144.0f;
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

      // sorting
      // -------
      // 8-bit per pass → 4 passes for 32-bit keys (technically can be hash size)
      for (unsigned int pass = 0; pass < 4; pass++) {
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, histogramSSBO);
        glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, nullptr);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

        radixSortCount.use();
        radixSortCount.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
        radixSortCount.uniform("smoothingRadius", smoothingRadius);
        radixSortCount.uniform("lookAhead", lookAhead);
        radixSortCount.uniform("pass", pass);
        glDispatchCompute((unsigned int)nParticles / WORKGROUP_SIZE, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

        radixSortScan.use();
        curr_n = ceil(static_cast<float>(nParticles) / WORKGROUP_SIZE) * RADIX;
        unsigned int offset = 0;
        while (curr_n > 1) {
          radixSortScan.uniform("offset", (unsigned int)offset);
          radixSortScan.uniform("g_offsets_size", (unsigned int)total_n);
          offset += ceil(static_cast<float>(curr_n) / WORKGROUP_SIZE) * WORKGROUP_SIZE;

          glDispatchCompute((unsigned int)ceil(static_cast<float>(curr_n) / WORKGROUP_SIZE), 1, 1);
          glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

          curr_n /= WORKGROUP_SIZE;
        }

        radixSortScatter.use();
        radixSortScatter.uniform("pass", pass);
        radixSortScatter.uniform("nParticles", (unsigned int)nParticles);
        glDispatchCompute((unsigned int)nParticles / WORKGROUP_SIZE, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
      }

      glBindBuffer(GL_SHADER_STORAGE_BUFFER, hashIndicesSSBO);
      glClearBufferData(
        GL_SHADER_STORAGE_BUFFER, GL_R32UI, GL_RED_INTEGER, GL_UNSIGNED_INT, &HASH_TABLE_SIZE
      );
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      hashIndices.use();
      glDispatchCompute((unsigned int)nParticles / WORKGROUP_SIZE, 1, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      // physics update
      // --------------
      sph1.use();
      sph1.uniform("nParticles", (unsigned int)nParticles);
      sph1.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
      sph1.uniform("smoothingRadius", smoothingRadius);
      sph1.uniform("lookAhead", lookAhead);
      glDispatchCompute((unsigned int)nParticles / 128, 1, 1);  // TODO make 128 a macro
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      sph2.use();
      sph2.uniform("deltaTime", deltaTime);
      sph2.uniform("nParticles", (unsigned int)nParticles);
      sph2.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
      sph2.uniform("smoothingRadius", smoothingRadius);
      sph2.uniform("lookAhead", lookAhead);
      sph2.uniform("tankLength", tankLength);
      sph2.uniform("tankHeight", tankHeight);
      sph2.uniform("tankWidth", tankWidth);
      sph2.uniform("time", currTime);
      glDispatchCompute((unsigned int)nParticles / 128, 1, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

      accumulatedTime -= deltaTime;
    }

    glClearColor(0.6f, 0.88f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    particleShader.use();
    particleShader.uniform("view", state.camera.view());
    particleShader.uniform("projection", state.camera.projection());
    particleShader.uniform("nParticles", (unsigned int)nParticles);
    particleShader.uniform("smoothingRadius", smoothingRadius);
    particleShader.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
    particleShader.uniform("lookAhead", lookAhead);

    particle.draw(nParticles);

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
