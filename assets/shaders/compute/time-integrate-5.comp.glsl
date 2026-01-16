#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 2) buffer VelocitiesFrontBuffer {
  float g_velocities_front[];
};

layout(std430, binding = 12) readonly buffer DeltaVelocitiesBuffer {
  float g_delta_velocities[];
};

uniform uint particle_count;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;
  vec3 velocity_i = vec3(g_velocities_front[3 * i + 0],
                         g_velocities_front[3 * i + 1],
                         g_velocities_front[3 * i + 2]);
  vec3 delta_velocity_i = vec3(g_delta_velocities[3 * i + 0],
                               g_delta_velocities[3 * i + 1],
                               g_delta_velocities[3 * i + 2]);

  velocity_i += delta_velocity_i;

  g_velocities_front[3 * i + 0] = velocity_i.x;
  g_velocities_front[3 * i + 1] = velocity_i.y;
  g_velocities_front[3 * i + 2] = velocity_i.z;
}
