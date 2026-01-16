#define RADIX 256
#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

// clang-format off
#include <glad/glad.h>
#include <GLFW/glfw3.h>
// clang-format on

#include <cassert>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <vector>

#include "Camera.hpp"
#include "ComputeShader.hpp"
#include "RenderShader.hpp"
#include "Texture.hpp"
#include "tracy/Tracy.hpp"
#include "tracy/TracyOpenGL.hpp"

#define TRACY_ON_DEMAND

const float fovy = 45.0f;
int width = 1920;  // bad being overwritten
int height = 1080;
const float near = 0.01f;
const float far = 100.0f;
const bool throttle = true;
const bool fullscreen = true;

const float speed = 5.0f;
const float sensitivity = 0.05f;

const float tank_length = 2.0f;
const float tank_width = 2.0f;
const float tank_height = 2.0f;

struct State {
  bool is_moving_forward = false;
  bool is_moving_backward = false;
  bool is_moving_leftward = false;
  bool is_moving_rightward = false;
  bool is_moving_upward = false;
  bool is_moving_downward = false;
  bool is_paused = false;
  bool is_resetting_simulation = false;
  bool is_resetting_camera = false;

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

    if (key == GLFW_KEY_R) {
      state.is_resetting_simulation = !state.is_resetting_simulation;
      return;
    }

    if (key == GLFW_KEY_X) {
      state.is_resetting_camera = !state.is_resetting_camera;
      return;
    }

    if (key == GLFW_KEY_W) {
      state.is_moving_forward = true;
      return;
    }
    if (key == GLFW_KEY_S) {
      state.is_moving_backward = true;
      return;
    }
    if (key == GLFW_KEY_D) {
      state.is_moving_rightward = true;
      return;
    }
    if (key == GLFW_KEY_A) {
      state.is_moving_leftward = true;
      return;
    }
    if (key == GLFW_KEY_SPACE) {
      state.is_moving_upward = true;
      return;
    }
    if (key == GLFW_KEY_LEFT_SHIFT) {
      state.is_moving_downward = true;
      return;
    }
  }

  if (action == GLFW_RELEASE) {
    if (key == GLFW_KEY_W) {
      state.is_moving_forward = false;
      return;
    }
    if (key == GLFW_KEY_S) {
      state.is_moving_backward = false;
      return;
    }
    if (key == GLFW_KEY_D) {
      state.is_moving_rightward = false;
      return;
    }
    if (key == GLFW_KEY_A) {
      state.is_moving_leftward = false;
      return;
    }
    if (key == GLFW_KEY_SPACE) {
      state.is_moving_upward = false;
      return;
    }
    if (key == GLFW_KEY_LEFT_SHIFT) {
      state.is_moving_downward = false;
      return;
    }
  }
}

GLuint quad() {
  GLuint VAO;
  GLuint VBO;
  GLuint EBO;

  float vertices[] = {
    // clang-format off
    -0.04f,  0.04f, 0.0f, 0.0f, 1.0f,
    -0.04f, -0.04f, 0.0f, 0.0f, 0.0f,
     0.04f,  0.04f, 0.0f, 1.0f, 1.0f,
     0.04f, -0.04f, 0.0f, 1.0f, 0.0f
    // clang-format on
  };
  uint32_t triangles[] = {
    // clang-format off
    0, 1, 2,
    2, 1, 3
    // clang-format on
  };

  glCreateBuffers(1, &VBO);
  glNamedBufferStorage(VBO, sizeof(vertices), vertices, GL_DYNAMIC_STORAGE_BIT);

  glCreateBuffers(1, &EBO);
  glNamedBufferStorage(EBO, sizeof(triangles), triangles, GL_DYNAMIC_STORAGE_BIT);

  glCreateVertexArrays(1, &VAO);

  glVertexArrayVertexBuffer(VAO, 0, VBO, 0, sizeof(float) * 5);
  glVertexArrayElementBuffer(VAO, EBO);

  glEnableVertexArrayAttrib(VAO, 0);
  glEnableVertexArrayAttrib(VAO, 1);

  glVertexArrayAttribFormat(VAO, 0, 3, GL_FLOAT, GL_FALSE, 0);
  glVertexArrayAttribFormat(VAO, 1, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 3);

  glVertexArrayAttribBinding(VAO, 0, 0);
  glVertexArrayAttribBinding(VAO, 1, 0);

  return VAO;
}

GLuint tank() {
  GLuint VAO;
  GLuint VBO;
  GLuint EBO;

  float vertices[] = {
    // clang-format off
     tank_length, -tank_height, -tank_width,
     tank_length, -tank_height,  tank_width,
    -tank_length, -tank_height,  tank_width,
    -tank_length, -tank_height, -tank_width,
     tank_length,  tank_height, -tank_width,
     tank_length,  tank_height,  tank_width,
    -tank_length,  tank_height,  tank_width,
    -tank_length,  tank_height, -tank_width
    // clang-format on
  };
  uint32_t triangles[] = {
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
    4, 0, 7
    // clang-format on
  };

  glCreateBuffers(1, &VBO);
  glNamedBufferStorage(VBO, sizeof(vertices), vertices, GL_DYNAMIC_STORAGE_BIT);

  glCreateBuffers(1, &EBO);
  glNamedBufferStorage(EBO, sizeof(triangles), triangles, GL_DYNAMIC_STORAGE_BIT);

  glCreateVertexArrays(1, &VAO);

  glVertexArrayVertexBuffer(VAO, 0, VBO, 0, sizeof(float) * 3);
  glVertexArrayElementBuffer(VAO, EBO);

  glEnableVertexArrayAttrib(VAO, 0);

  glVertexArrayAttribFormat(VAO, 0, 3, GL_FLOAT, GL_FALSE, 0);

  glVertexArrayAttribBinding(VAO, 0, 0);

  return VAO;
}

/*
Each particle conducts a linear neighborhood search.
All particles in a workgroup are spatially close to each other because the particles are
periodically sorted according to their Morton code. So, their neighors are also the same, and the
cache-hit rate is high.
Particles move gradually across each time step, so the cache-hit rate remains high.

Pausing the simulation does NOT improve performance for subsequent frames, so it is not a caching
issue. Probably, it's with particles on the boundaries, since many MANY particles get trapped there.

L2 cache is shared across ALL SMs.
L1 cache is shared within workgroups in an SM.

*/

int main() {
  glfwInit();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  glfwWindowHint(GLFW_SAMPLES, 4);

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
  // glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  // glEnable(GL_BLEND);

  state.camera = Camera(fovy, width, height, near, far);  // bad
  state.camera.translateTo(glm::vec3(0.0, 0.0, 10.0));
  state.camera.rotateTo(glm::vec2(0.0, -90.0));

  RenderShader particleShader, tankShader;
  ComputeShader time_integrate_1, time_integrate_2_1, time_integrate_2_2, time_integrate_2_3,
    time_integrate_3, time_integrate_4, time_integrate_5, radix_sort_particle_handles_0,
    radix_sort_particle_handles_1, radix_sort_particle_handles_2, radix_sort_particle_handles_3,
    radixSortSwap, hashIndicesClear, compute_particle_handle_offsets, init_particles,
    sort_particles, sortParticles2;
  try {
    particleShader.build(
      "./assets/shaders/render/particle.vert.glsl", "./assets/shaders/render/particle.frag.glsl"
    );
    tankShader.build(
      "./assets/shaders/render/tank.vert.glsl", "./assets/shaders/render/tank.frag.glsl"
    );

    time_integrate_1.build("./assets/shaders/compute/time-integrate-1.comp.glsl");
    time_integrate_2_1.build("./assets/shaders/compute/time-integrate-2.1.comp.glsl");
    time_integrate_2_2.build("./assets/shaders/compute/time-integrate-2.2.comp.glsl");
    time_integrate_2_3.build("./assets/shaders/compute/time-integrate-2.3.comp.glsl");
    time_integrate_3.build("./assets/shaders/compute/time-integrate-3.comp.glsl");
    time_integrate_4.build("./assets/shaders/compute/time-integrate-4.comp.glsl");
    time_integrate_5.build("./assets/shaders/compute/time-integrate-5.comp.glsl");
    radix_sort_particle_handles_0.build(
      "./assets/shaders/compute/(radix)-sort-particle-handles-0-hash.comp.glsl"
    );
    radix_sort_particle_handles_1.build(
      "./assets/shaders/compute/(radix)-sort-particle-handles-1-count.comp.glsl"
    );
    radix_sort_particle_handles_2.build(
      "./assets/shaders/compute/(radix)-sort-particle-handles-2-scan.comp.glsl"
    );
    radix_sort_particle_handles_3.build(
      "./assets/shaders/compute/(radix)-sort-particle-handles-3-scatter.comp.glsl"
    );
    compute_particle_handle_offsets.build(
      "./assets/shaders/compute/compute-particle-handle-offsets.comp.glsl"
    );
    init_particles.build("./assets/shaders/compute/init-particles.comp.glsl");
    sort_particles.build("./assets/shaders/compute/sort-particles.comp.glsl");
  } catch (const std::exception& err) {
    std::cerr << err.what();
    return 1;
  }

  // TODO: wrap everything in the try-catch

  Texture densityGradient{"./assets/textures/density-gradient.png"};
  densityGradient.use(0);

  const float h = 0.1f;
  const uint32_t particle_count = 32 * 32 * 32;
  const float mass = 1.0f;
  const float density_rest = 20.0f;
  const uint32_t HASH_TABLE_SIZE =
    WORKGROUP_SIZE * 32;  // 2 * particle_count is recommended (Ihmsen et al.)

  // (Green, 2008) neighbor search
  // (Bridson et al, 2006) fluid-solid collision
  //
  // an idea: use delta_pos, delta_vel as the back buffer?
  //
  // start with: cleaning up front/back buffers, apply vorticity
  // note: computation cost increases when a method fails to maintain fluid density and particles
  // begin to have more neighbors. initialization is still important.
  //
  // coloring particles with density is a helpful visual check
  // repulsive term vs. negative pressure clamping?

  // particle_count should also fully saturate WORKGROUP
  static_assert(WORKGROUP_SIZE >= RADIX);

  GLuint g_positions;
  glCreateBuffers(1, &g_positions);
  glObjectLabel(GL_BUFFER, g_positions, -1, "g_positions");
  glNamedBufferStorage(
    g_positions, sizeof(float) * 3 * particle_count, nullptr, GL_DYNAMIC_STORAGE_BIT
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, g_positions);

  GLuint g_velocities;
  glCreateBuffers(1, &g_velocities);
  glObjectLabel(GL_BUFFER, g_velocities, -1, "g_velocities");
  glNamedBufferStorage(
    g_velocities, sizeof(float) * 3 * particle_count, nullptr, GL_DYNAMIC_STORAGE_BIT
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, g_velocities);

  GLuint g_positions_pred;
  glCreateBuffers(1, &g_positions_pred);
  glObjectLabel(GL_BUFFER, g_positions_pred, -1, "g_positions_pred");
  glNamedBufferStorage(
    g_positions_pred, sizeof(float) * 3 * particle_count, nullptr, GL_DYNAMIC_STORAGE_BIT
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, g_positions_pred);

  GLuint g_delta_positions;
  glCreateBuffers(1, &g_delta_positions);
  glObjectLabel(GL_BUFFER, g_delta_positions, -1, "g_delta_positions");
  glNamedBufferStorage(
    g_delta_positions, sizeof(float) * 3 * particle_count, nullptr, GL_DYNAMIC_STORAGE_BIT
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, g_delta_positions);

  GLuint g_delta_velocities;
  glCreateBuffers(1, &g_delta_velocities);
  glObjectLabel(GL_BUFFER, g_delta_velocities, -1, "g_delta_velocities");
  glNamedBufferStorage(
    g_delta_velocities, sizeof(float) * 3 * particle_count, nullptr, GL_DYNAMIC_STORAGE_BIT
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 4, g_delta_velocities);

  // g_grad_kernel

  GLuint g_multipliers;
  glCreateBuffers(1, &g_multipliers);
  glObjectLabel(GL_BUFFER, g_multipliers, -1, "g_multipliers");
  glNamedBufferStorage(
    g_multipliers, sizeof(float) * particle_count, nullptr, GL_DYNAMIC_STORAGE_BIT
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 5, g_multipliers);

  struct ParticleHandle {
    uint32_t hash;
    uint32_t index;
  };

  GLuint g_particle_handles;
  glCreateBuffers(1, &g_particle_handles);
  glObjectLabel(GL_BUFFER, g_particle_handles, -1, "g_particle_handles");
  {
    std::vector<ParticleHandle> particle_handles_front(particle_count);
    for (int i = 0; i < particle_count; i++) {
      particle_handles_front[i].index = i;
    }

    glNamedBufferStorage(
      g_particle_handles,
      sizeof(ParticleHandle) * particle_count,
      particle_handles_front.data(),
      GL_DYNAMIC_STORAGE_BIT
    );
  }
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 6, g_particle_handles);

  GLuint g_particle_handles_copy;
  glCreateBuffers(1, &g_particle_handles_copy);
  glObjectLabel(GL_BUFFER, g_particle_handles_copy, -1, "g_particle_handles_copy");
  glNamedBufferStorage(
    g_particle_handles_copy,
    sizeof(ParticleHandle) * particle_count,
    nullptr,
    GL_DYNAMIC_STORAGE_BIT
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 7, g_particle_handles_copy);

  GLuint g_particle_handle_offsets;
  glCreateBuffers(1, &g_particle_handle_offsets);
  glObjectLabel(GL_BUFFER, g_particle_handle_offsets, -1, "g_particle_handle_offsets");
  glNamedBufferStorage(
    g_particle_handle_offsets, sizeof(uint32_t) * HASH_TABLE_SIZE, nullptr, GL_DYNAMIC_STORAGE_BIT
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 8, g_particle_handle_offsets);

  uint32_t total_n = 0;
  uint32_t curr_n = (particle_count + WORKGROUP_SIZE - 1) / WORKGROUP_SIZE * RADIX;
  while (curr_n > 1) {
    total_n += (curr_n + WORKGROUP_SIZE - 1) / WORKGROUP_SIZE * WORKGROUP_SIZE;
    curr_n /= WORKGROUP_SIZE;
  }
  GLuint g_histogram;
  glCreateBuffers(1, &g_histogram);
  glObjectLabel(GL_BUFFER, g_histogram, -1, "g_histogram");
  glNamedBufferStorage(g_histogram, sizeof(uint32_t) * total_n, nullptr, GL_DYNAMIC_STORAGE_BIT);
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 9, g_histogram);
  glClearNamedBufferData(g_histogram, GL_R32UI, GL_RED_INTEGER, GL_UNSIGNED_INT, nullptr);
  glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

  GLuint g_debug;
  glCreateBuffers(1, &g_debug);
  glObjectLabel(GL_BUFFER, g_debug, -1, "g_debug");
  glNamedBufferStorage(
    g_debug, 3 * sizeof(float) * particle_count, nullptr, GL_DYNAMIC_STORAGE_BIT
  );
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 11, g_debug);
  glClearNamedBufferData(g_debug, GL_R8UI, GL_RED_INTEGER, GL_UNSIGNED_BYTE, nullptr);
  glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

  init_particles.use();
  init_particles.uniform("mass", mass);
  init_particles.uniform("particle_count", particle_count);
  init_particles.uniform("h", h);
  init_particles.uniform("density_rest", density_rest);
  glDispatchCompute(particle_count / WORKGROUP_SIZE, 1, 1);
  glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

  GLuint quadVAO = quad();
  GLuint tankVAO = tank();

  const float delta_time = 0.0069f;
  float prev_time = glfwGetTime();
  float accumulated_time = 0.0f;

  uint32_t particle_sort_iters = 0;

  TracyGpuContext;
  while (!glfwWindowShouldClose(window)) {
    auto origin = state.camera.origin();
    auto [u, v, w] = state.camera.basis();

    float curr_time = glfwGetTime();
    accumulated_time += curr_time - prev_time;
    prev_time = curr_time;

    while (accumulated_time >= delta_time) {
      glm::vec3 delta = glm::vec3(0.0);
      if (state.is_moving_forward) delta -= w * speed * delta_time;
      if (state.is_moving_backward) delta += w * speed * delta_time;
      if (state.is_moving_leftward) delta -= u * speed * delta_time;
      if (state.is_moving_rightward) delta += u * speed * delta_time;
      if (state.is_moving_downward) delta -= v * speed * delta_time;
      if (state.is_moving_upward) delta += v * speed * delta_time;
      state.camera.translateBy(delta);

      if (state.is_resetting_simulation) {
        init_particles.use();
        init_particles.uniform("particle_count", particle_count);
        glDispatchCompute(particle_count / WORKGROUP_SIZE, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
        state.is_resetting_simulation = false;
      }

      if (state.is_resetting_camera) {
        state.camera.translateTo(glm::vec3(0.0, 0.0, 10.0));
        state.camera.rotateTo(glm::vec2(0.0, -90.0));
        state.is_resetting_camera = false;
      }

      {
        TracyGpuZone("time-integrate-1");
        glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "time-integrate-1");

        time_integrate_1.use();
        time_integrate_1.uniform("particle_count", particle_count);
        time_integrate_1.uniform("delta_time", delta_time);
        time_integrate_1.uniform("h", h);
        time_integrate_1.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
        glDispatchCompute(particle_count / 128, 1, 1);  // TODO make 128 a macro
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
        glPopDebugGroup();
      }

      {
        TracyGpuZone("(radix)-sort-particle-handles");
        glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "(radix)-sort-particle-handles");

        {
          TracyGpuZone("(radix)-sort-particle-handles-0-hash");
          glPushDebugGroup(
            GL_DEBUG_SOURCE_APPLICATION, 0, -1, "(radix)-sort-particle-handles-0-hash"
          );

          radix_sort_particle_handles_0.use();
          radix_sort_particle_handles_0.uniform("particle_count", particle_count);
          radix_sort_particle_handles_0.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
          radix_sort_particle_handles_0.uniform("h", h);
          glDispatchCompute(particle_count / WORKGROUP_SIZE, 1, 1);
          glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
          glPopDebugGroup();
        }

        // sorting particle handles
        // ------------------------
        // 8 bits per pass → 4 passes for 32-bit keys
        for (uint32_t pass = 0; pass < 4; pass++) {
          glClearNamedBufferData(g_histogram, GL_R32UI, GL_RED_INTEGER, GL_UNSIGNED_INT, nullptr);
          glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

          {
            TracyGpuZone("(radix)-sort-particle-handles-1-count");
            glPushDebugGroup(
              GL_DEBUG_SOURCE_APPLICATION, 0, -1, "(radix)-sort-particle-handles-1-count"
            );

            radix_sort_particle_handles_1.use();
            radix_sort_particle_handles_1.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
            radix_sort_particle_handles_1.uniform("h", h);
            radix_sort_particle_handles_1.uniform("pass", pass);
            glDispatchCompute(particle_count / WORKGROUP_SIZE, 1, 1);
            glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
            glPopDebugGroup();
          }

          {
            TracyGpuZone("(radix)-sort-particle-handles-2-scan");
            glPushDebugGroup(
              GL_DEBUG_SOURCE_APPLICATION, 0, -1, "(radix)-sort-particle-handles-2-scan"
            );

            radix_sort_particle_handles_2.use();
            curr_n = ceil(static_cast<float>(particle_count) / WORKGROUP_SIZE) * RADIX;
            uint32_t offset = 0;
            while (curr_n > 1) {
              radix_sort_particle_handles_2.uniform("offset", (unsigned int)offset);
              radix_sort_particle_handles_2.uniform("g_offsets_size", (unsigned int)total_n);
              offset += (curr_n + WORKGROUP_SIZE - 1) / WORKGROUP_SIZE * WORKGROUP_SIZE;

              glDispatchCompute((uint32_t)(curr_n + WORKGROUP_SIZE - 1) / WORKGROUP_SIZE, 1, 1);
              glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

              curr_n /= WORKGROUP_SIZE;
            }
            glPopDebugGroup();
          }

          {
            TracyGpuZone("(radix)-sort-particle-handles-3-scatter");
            glPushDebugGroup(
              GL_DEBUG_SOURCE_APPLICATION, 0, -1, "(radix)-sort-particle-handles-3-scatter"
            );

            radix_sort_particle_handles_3.use();
            radix_sort_particle_handles_3.uniform("pass", pass);
            radix_sort_particle_handles_3.uniform("particle_count", (unsigned int)particle_count);
            glDispatchCompute(particle_count / WORKGROUP_SIZE, 1, 1);
            glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
            glPopDebugGroup();
          }
        }

        glPopDebugGroup();
      }

      {
        TracyGpuZone("compute-particle-handle-offsets");
        glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "compute-particle-handle-offsets");

        // maybe clear it to HASH_TABLE_SIZE once, then launch shader for particle_count to write
        // the stuff if different from previous one to clear
        glClearNamedBufferData(
          g_particle_handle_offsets, GL_R32UI, GL_RED_INTEGER, GL_UNSIGNED_INT, &HASH_TABLE_SIZE
        );
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

        compute_particle_handle_offsets.use();
        compute_particle_handle_offsets.uniform("particle_count", particle_count);
        glDispatchCompute(particle_count / WORKGROUP_SIZE, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
        glPopDebugGroup();
      }

      // physics update
      // --------------
      uint32_t iters = 4;
      for (uint32_t iter = 0; iter < iters; iter++) {
        {
          TracyGpuZone("time-integrate-2.1");
          glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "time-integrate-2.1");

          time_integrate_2_1.use();
          time_integrate_2_1.uniform("mass", mass);
          time_integrate_2_1.uniform("particle_count", particle_count);
          time_integrate_2_1.uniform("h", h);
          time_integrate_2_1.uniform("density_rest", density_rest);
          time_integrate_2_1.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
          glDispatchCompute(particle_count / 128, 1, 1);
          glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
          glPopDebugGroup();
        }

        {
          TracyGpuZone("time-integrate-2.2");
          glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "time-integrate-2.2");

          time_integrate_2_2.use();
          time_integrate_2_2.uniform("mass", mass);
          time_integrate_2_2.uniform("particle_count", particle_count);
          time_integrate_2_2.uniform("h", h);
          time_integrate_2_2.uniform("density_rest", density_rest);
          time_integrate_2_2.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
          time_integrate_2_2.uniform("tank_length", tank_length);
          time_integrate_2_2.uniform("tank_width", tank_width);
          time_integrate_2_2.uniform("tank_height", tank_height);
          glDispatchCompute(particle_count / 128, 1, 1);
          glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
          glPopDebugGroup();
        }

        {
          TracyGpuZone("time-integrate-2.3");
          glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "time-integrate-2.3");

          time_integrate_2_3.use();
          time_integrate_2_3.uniform("particle_count", particle_count);
          glDispatchCompute(particle_count / 128, 1, 1);
          glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
          glPopDebugGroup();
        }
      }

      {
        TracyGpuZone("time-integrate-3");
        glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "time-integrate-3");

        time_integrate_3.use();
        time_integrate_3.uniform("particle_count", particle_count);
        time_integrate_3.uniform("delta_time", delta_time);
        glDispatchCompute(particle_count / 128, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
        glPopDebugGroup();
      }

      {
        TracyGpuZone("time-integrate-4");
        glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "time-integrate-4");

        time_integrate_4.use();
        time_integrate_4.uniform("mass", mass);
        time_integrate_4.uniform("particle_count", particle_count);
        time_integrate_4.uniform("h", h);
        time_integrate_4.uniform("density_rest", density_rest);
        time_integrate_4.uniform("HASH_TABLE_SIZE", HASH_TABLE_SIZE);
        glDispatchCompute(particle_count / 128, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
        glPopDebugGroup();
      }

      {
        TracyGpuZone("time-integrate-5");
        glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "time-integrate-5");

        time_integrate_5.use();
        time_integrate_5.uniform("particle_count", particle_count);
        glDispatchCompute(particle_count / 128, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
        glPopDebugGroup();
      }

      // maybe there's a better place for this
      // 30-40 ms without
      // 2 + 5 ms with (for sorting every 10 frames)
      // This makes a huge difference.
      if (particle_sort_iters == 8) {  // anywhere between 1-100 time steps is recommended
        // sort particles (helps coalesce reads/writes into GPU memory)
        // ------------------------------------------------------------
        {
          TracyGpuZone("sort-particles");
          glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, 0, -1, "sort-particles");

          sort_particles.use();
          sort_particles.uniform("particle_count", particle_count);
          glDispatchCompute(particle_count / WORKGROUP_SIZE, 1, 1);
          glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

          // reuse g_delta_positions and g_delta_positions as g_positions_copy and g_velocities_copy
          // for double buffering
          glCopyNamedBufferSubData(
            g_delta_positions, g_positions, 0, 0, sizeof(float) * 3 * particle_count
          );
          glCopyNamedBufferSubData(
            g_delta_velocities, g_velocities, 0, 0, sizeof(float) * 3 * particle_count
          );
          glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
          glPopDebugGroup();
        }

        particle_sort_iters = 0;
      }
      particle_sort_iters++;

      accumulated_time -= delta_time;

      break;  // TODO: REMOVE THIS (this limits 1 physics update per frame)
    }

    glClearColor(0.2f, 0.2f, 0.2f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    {
      TracyGpuZone("particle-shader");

      particleShader.use();
      particleShader.uniform("camera.view", state.camera.view());
      particleShader.uniform("camera.projection", state.camera.projection());
      particleShader.uniform("camera.u", u);
      particleShader.uniform("camera.v", v);
      particleShader.uniform("camera.w", w);
      particleShader.uniform("particle_count", particle_count);

      glBindVertexArray(quadVAO);
      glDrawElementsInstanced(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0, particle_count);
      glBindVertexArray(0);
    }

    {
      TracyGpuZone("tank-shader");
      tankShader.use();
      tankShader.uniform("model", glm::mat4(1.0));
      tankShader.uniform("view", state.camera.view());
      tankShader.uniform("projection", state.camera.projection());

      glBindVertexArray(tankVAO);
      glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
      glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_INT, 0);
      glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
      glBindVertexArray(0);
    }

    glfwSwapBuffers(window);
    glfwPollEvents();

    TracyGpuCollect;
    FrameMark;
  }

  glDeleteBuffers(1, &g_positions);
  glDeleteBuffers(1, &g_velocities);
  glDeleteBuffers(1, &g_positions_pred);
  glDeleteBuffers(1, &g_delta_positions);
  glDeleteBuffers(1, &g_delta_velocities);
  glDeleteBuffers(1, &g_multipliers);
  glDeleteBuffers(1, &g_particle_handles);
  glDeleteBuffers(1, &g_particle_handles_copy);
  glDeleteBuffers(1, &g_particle_handle_offsets);
  glDeleteBuffers(1, &g_histogram);
  glDeleteBuffers(1, &g_debug);

  // TODO: also VAO, VBOs, EBOs

  glfwTerminate();
  return 0;
}
