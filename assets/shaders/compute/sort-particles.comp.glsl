#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer PositionsFrontBuffer {
  float g_positions_front[];
};

layout(std430, binding = 1) buffer PositionsBackBuffer {
  float g_positions_back[];
};

layout(std430, binding = 2) readonly buffer VelocitiesFrontBuffer {
  float g_velocities_front[];
};

layout(std430, binding = 3) buffer VelocitiesBackBuffer {
  float g_velocities_back[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 7) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_particle_handles_front[];
};

uniform uint particle_count;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;
  ParticleHandle handle = g_particle_handles_front[i];

  g_positions_back[3 * i + 0] = g_positions_front[3 * handle.index + 0];
  g_positions_back[3 * i + 1] = g_positions_front[3 * handle.index + 1];
  g_positions_back[3 * i + 2] = g_positions_front[3 * handle.index + 2];
  g_velocities_back[3 * i + 0] = g_velocities_front[3 * handle.index + 0];
  g_velocities_back[3 * i + 1] = g_velocities_front[3 * handle.index + 1];
  g_velocities_back[3 * i + 2] = g_velocities_front[3 * handle.index + 2];

  handle.index = i;
  g_particle_handles_front[i] = handle;
}
