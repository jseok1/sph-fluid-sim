#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer PositionsBuffer {
  float g_positions[];
};

layout(std430, binding = 1) buffer VelocitiesBuffer {
  float g_velocities[];
};

uniform float mass;
uniform uint particle_count;
uniform float h;
uniform float density_rest;
uniform uint scenario;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;

  float x, y, z;

  if (scenario == 1) {
    float s = 5;  // side length of water cube (should depend on smoothing radius)
    float n = ceil(pow(particle_count, 1.0 / 3.0));
    x = mod(i, n) * s / n - s / 2.0;
    y = floor(mod(i, n * n) / n) * s / n - s / 2.0;
    z = floor(i / (n * n)) * s / n - s / 2.0;
  } else if (scenario == 2) {
    float s = 3.5;

    if (i < particle_count / 2) {
      float n = ceil(pow(particle_count / 2, 1.0 / 3.0));
      x = mod(i, n) * s / n - s / 2.0 - 3.0;
      y = floor(mod(i, n * n) / n) * s / n - s / 2.0;
      z = floor(i / (n * n)) * s / n - s / 2.0 - 0.5;
    } else {
      float n = ceil(pow(particle_count / 2, 1.0 / 3.0));
      x = mod(i - particle_count / 2, n) * s / n - s / 2.0 + 3.0;
      y = floor(mod(i - particle_count / 2, n * n) / n) * s / n - s / 2.0;
      z = floor((i - particle_count / 2) / (n * n)) * s / n - s / 2.0 + 0.5;
    }
  }

  vec3 position_i = vec3(x, y, z);
  vec3 velocity_i = vec3(0.0);

  g_positions[3 * i + 0] = position_i.x;
  g_positions[3 * i + 1] = position_i.y;
  g_positions[3 * i + 2] = position_i.z;
  g_velocities[3 * i + 0] = velocity_i.x;
  g_velocities[3 * i + 1] = velocity_i.y;
  g_velocities[3 * i + 2] = velocity_i.z;
}

