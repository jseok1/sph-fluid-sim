#version 460 core

#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer PositionsPing {
  float g_positions_ping[];
};

layout(std430, binding = 7) buffer VelocitiesPing {
  float g_velocities_ping[];
};

layout(std430, binding = 10) readonly buffer PositionsPong {
  float g_positions_pong[];
};

layout(std430, binding = 11) readonly buffer VelocitiesPong {
  float g_velocities_pong[];
};

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  // should these "vec3"s be SoA?
  g_positions_ping[3 * g_tid] = g_positions_pong[3 * g_tid];
  g_positions_ping[3 * g_tid + 1] = g_positions_pong[3 * g_tid + 1];
  g_positions_ping[3 * g_tid + 2] = g_positions_pong[3 * g_tid + 2];
  g_velocities_ping[3 * g_tid] = g_velocities_pong[3 * g_tid];
  g_velocities_ping[3 * g_tid + 1] = g_velocities_pong[3 * g_tid + 1];
  g_velocities_ping[3 * g_tid + 2] = g_velocities_pong[3 * g_tid + 2];
}
