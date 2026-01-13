#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer PositionsFrontBuffer {
  float g_positions_front[];
};

layout(std430, binding = 2) buffer VelocitiesFrontBuffer {
  float g_velocities_front[];
};

layout(std430, binding = 4) readonly buffer PredictedPositionsBuffer {
  float g_positions_pred[];
};

uniform uint particle_count;
uniform float delta_time;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;
  vec3 position_i = vec3(g_positions_front[3 * i + 0],
                         g_positions_front[3 * i + 1],
                         g_positions_front[3 * i + 2]);
  vec3 position_pred_i = vec3(g_positions_pred[3 * i + 0],
                              g_positions_pred[3 * i + 1],
                              g_positions_pred[3 * i + 2]);

  vec3 velocity_i = (position_pred_i - position_i) / delta_time;

  g_positions_front[3 * i + 0] = position_pred_i.x;
  g_positions_front[3 * i + 1] = position_pred_i.y;
  g_positions_front[3 * i + 2] = position_pred_i.z;
 
  g_velocities_front[3 * i + 0] = velocity_i.x;
  g_velocities_front[3 * i + 1] = velocity_i.y;
  g_velocities_front[3 * i + 2] = velocity_i.z;

  // TODO: vorticity confinement and viscosity
}

