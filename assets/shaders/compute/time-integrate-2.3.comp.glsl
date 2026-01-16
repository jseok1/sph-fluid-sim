#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 2) buffer PredictedPositionsBuffer {
  float g_positions_pred[];
};

layout(std430, binding = 3) readonly buffer DeltaPositionsBuffer {
  float g_delta_positions[];
};

uniform uint particle_count;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;
  vec3 position_pred_i = vec3(g_positions_pred[3 * i + 0],
                              g_positions_pred[3 * i + 1],
                              g_positions_pred[3 * i + 2]);
  vec3 delta_position_i = vec3(g_delta_positions[3 * i + 0],
                               g_delta_positions[3 * i + 1],
                               g_delta_positions[3 * i + 2]);

  position_pred_i += delta_position_i;

  g_positions_pred[3 * i + 0] = position_pred_i.x;
  g_positions_pred[3 * i + 1] = position_pred_i.y;
  g_positions_pred[3 * i + 2] = position_pred_i.z;
}

