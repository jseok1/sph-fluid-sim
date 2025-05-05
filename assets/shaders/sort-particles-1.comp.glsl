#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer PositionsPing {
  float g_positions_ping[];
};

layout(std430, binding = 7) readonly buffer VelocitiesPing {
  float g_velocities_ping[];
};

layout(std430, binding = 10) buffer PositionsPong {
  float g_positions_pong[];
};

layout(std430, binding = 11) buffer VelocitiesPong {
  float g_velocities_pong[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 2) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  ParticleHandle handle = g_handles_front[g_tid];

  g_positions_pong[3 * g_tid] = g_positions_ping[3 * handle.index];
  g_positions_pong[3 * g_tid + 1] = g_positions_ping[3 * handle.index + 1];
  g_positions_pong[3 * g_tid + 2] = g_positions_ping[3 * handle.index + 2];
  g_velocities_pong[3 * g_tid] = g_velocities_ping[3 * handle.index];
  g_velocities_pong[3 * g_tid + 1] = g_velocities_ping[3 * handle.index + 1];
  g_velocities_pong[3 * g_tid + 2] = g_velocities_ping[3 * handle.index + 2];

  handle.index = g_tid;
  g_handles_front[g_tid] = handle;
}
