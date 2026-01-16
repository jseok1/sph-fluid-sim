#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer PositionsBuffer {
  float g_positions[];
};

layout(std430, binding = 1) readonly buffer VelocitiesBuffer {
  float g_velocities[];
};

// This is also g_delta_positions in other kernels.
layout(std430, binding = 3) buffer PositionsBufferCopy {
  float g_positions_copy[];
};

// This is also g_delta_velocities in other kernels.
layout(std430, binding = 4) buffer VelocitiesBufferCopy {
  float g_velocities_copy[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 6) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_particle_handles[];
};

uniform uint particle_count;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;
  ParticleHandle handle = g_particle_handles[i];

  g_positions_copy[3 * i + 0] = g_positions[3 * handle.index + 0];
  g_positions_copy[3 * i + 1] = g_positions[3 * handle.index + 1];
  g_positions_copy[3 * i + 2] = g_positions[3 * handle.index + 2];
  g_velocities_copy[3 * i + 0] = g_velocities[3 * handle.index + 0];
  g_velocities_copy[3 * i + 1] = g_velocities[3 * handle.index + 1];
  g_velocities_copy[3 * i + 2] = g_velocities[3 * handle.index + 2];

  handle.index = i;
  g_particle_handles[i] = handle;
}
