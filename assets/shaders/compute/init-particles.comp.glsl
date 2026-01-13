#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer PositionsFrontBuffer {
  float g_positions_front[];
};

layout(std430, binding = 2) buffer VelocitiesFrontBuffer {
  float g_velocities_front[];
};

uniform uint particle_count;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;

  float s = 2.0;  // side length of water cube (should depend on smoothing radius)
  float n = ceil(pow(particle_count, 1.0 / 3.0));
  float x = mod(i, n) * s / n - s / 2.0;
  float y = floor(mod(i, n * n) / n) * s / n - s / 2.0;
  float z = floor(i / (n * n)) * s / n - s / 2.0;

  vec3 position_i = vec3(x, y, z);
  vec3 velocity_i = vec3(0.0);

  g_positions_front[3 * i + 0] = position_i.x;
  g_positions_front[3 * i + 1] = position_i.y;
  g_positions_front[3 * i + 2] = position_i.z;
  g_velocities_front[3 * i + 0] = velocity_i.x;
  g_velocities_front[3 * i + 1] = velocity_i.y;
  g_velocities_front[3 * i + 2] = velocity_i.z;
}

