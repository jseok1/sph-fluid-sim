#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 4) readonly buffer PredictedPositionsBuffer {
  float g_positions_pred[];
};

layout(std430, binding = 5) buffer DeltaPositionsBuffer {
  float g_delta_positions[];
};

layout(std430, binding = 6) readonly buffer MultipliersBuffer {
  float g_multipliers[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 7) readonly buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_particle_handles_front[];
};

layout(std430, binding = 9) readonly buffer ParticleHandleOffsetsBuffer {
  uint g_particle_handle_offsets[];
};

layout(std430, binding = 11) buffer DebugBuffer {
  float g_debug[];
};

vec3 neighborhood[27] = {
  // clang-format off
  vec3(-1.0, -1.0, -1.0),
  vec3(-1.0, -1.0,  0.0),
  vec3(-1.0, -1.0,  1.0),
  vec3(-1.0,  0.0, -1.0),
  vec3(-1.0,  0.0,  0.0),
  vec3(-1.0,  0.0,  1.0),
  vec3(-1.0,  1.0, -1.0),
  vec3(-1.0,  1.0,  0.0),
  vec3(-1.0,  1.0,  1.0),
  vec3( 0.0, -1.0, -1.0),
  vec3( 0.0, -1.0,  0.0),
  vec3( 0.0, -1.0,  1.0),
  vec3( 0.0,  0.0, -1.0),
  vec3( 0.0,  0.0,  0.0),
  vec3( 0.0,  0.0,  1.0),
  vec3( 0.0,  1.0, -1.0),
  vec3( 0.0,  1.0,  0.0),
  vec3( 0.0,  1.0,  1.0),
  vec3( 1.0, -1.0, -1.0),
  vec3( 1.0, -1.0,  0.0),
  vec3( 1.0, -1.0,  1.0),
  vec3( 1.0,  0.0, -1.0),
  vec3( 1.0,  0.0,  0.0),
  vec3( 1.0,  0.0,  1.0),
  vec3( 1.0,  1.0, -1.0),
  vec3( 1.0,  1.0,  0.0),
  vec3( 1.0,  1.0,  1.0),
  // clang-format on
};

uniform float mass;
uniform uint particle_count;
uniform float h;
uniform float density_rest;
uniform uint HASH_TABLE_SIZE;
uniform float tank_length;
uniform float tank_width;
uniform float tank_height;

const float pi = 3.1415926535;

float tank_signed_distance(vec3 point) {
  vec3 q = abs(point) - vec3(tank_length, tank_height, tank_width);
  return -length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

uint interleave_bits(uint bits) {
  bits &= 0x000003FF;  // keep only 10 bits (3 x 10 bits = 30 bits <= 32 bits)
  bits = (bits | (bits << 16)) & 0x030000FF;  // 00000011 00000000 00000000 11111111
  bits = (bits | (bits << 8))  & 0x0300F00F;  // 00000011 00000000 11110000 00001111
  bits = (bits | (bits << 4))  & 0x030C30C3;  // 00000011 00001100 00110000 11000011
  bits = (bits | (bits << 2))  & 0x09249249;  // 00001001 00100100 10010010 01001001
  return bits;
}

uint hash(vec3 position) {
  // Morton code for locality-preserving hashing
  uint x = uint((position.x + 5) / h);
  uint y = uint((position.y + 5) / h);
  uint z = uint((position.z + 5) / h);
  uint hash = (interleave_bits(z) << 2) | (interleave_bits(y) << 1) | interleave_bits(x);
  hash = uint(mod(hash, HASH_TABLE_SIZE));  // better if bitwise &
  return hash;
}

float kernel(vec3 position_i, vec3 position_j) {
  // SPIKY
  float r = distance(position_i, position_j);
  float residual = max(0.0, h - r);
  return 15.0 / (pi * h * h * h * h * h * h) * residual * residual * residual;
}

vec3 grad_kernel(vec3 position_i, vec3 position_j) {
  // SPIKY
  float r = distance(position_i, position_j);
  vec3 direction = r > 1e-8 ? normalize(position_i - position_j) : vec3(0.0);
  float residual = max(0.0, h - r);
  return -45.0 / (pi * h * h * h * h * h * h) * residual * residual * direction;
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;
  vec3 position_pred_i = vec3(g_positions_pred[3 * i + 0],
                              g_positions_pred[3 * i + 1],
                              g_positions_pred[3 * i + 2]);

  // float normalization = kernel(vec3(0.0, 0.0, 0.0), vec3(0.1 * h, 0.1 * h, 0.1 * h));

  vec3 delta_position_i = vec3(0.0);
  for (uint p = 0; p < 27; p++) {
    uint hash = hash(position_pred_i + neighborhood[p] * h);
    uint q = g_particle_handle_offsets[hash];
    while (q < particle_count && g_particle_handles_front[q].hash == hash) {
      uint j = g_particle_handles_front[q].index;
      if (j != i) {
        vec3 position_pred_j = vec3(g_positions_pred[3 * j + 0],
                                    g_positions_pred[3 * j + 1],
                                    g_positions_pred[3 * j + 2]);

        // float kernel_i = kernel(position_pred_i, position_pred_j);

        float multiplier_i = g_multipliers[i];
        float multiplier_j = g_multipliers[j];

        // artificial pressure
        // float corr = kernel_i / normalization;
        // delta_position_i += (multiplier_i + multiplier_j - 0.1 * corr * corr * corr * corr) * grad_kernel_i;
        delta_position_i += (multiplier_i + multiplier_j) * mass * grad_kernel(position_pred_i, position_pred_j);
      }
      q++;
    }
  }
  delta_position_i /= density_rest;

  vec3 position_i = position_pred_i + delta_position_i;

  // g_debug[3 * i + 0] = position_i.x;
  // g_debug[3 * i + 1] = position_i.y;
  // g_debug[3 * i + 2] = position_i.z;
 
  if (position_i.x > tank_length) {
    position_i.x = tank_length - 0.9 * (position_i.x - tank_length);
  }
  if (position_i.x < -tank_length) {
    position_i.x = -tank_length - 0.9 * (position_i.x + tank_length);
  }
  if (position_i.y > tank_height) {
    position_i.y = tank_height - 0.9 * (position_i.y - tank_height);
  }
  if (position_i.y < -tank_height) {
    position_i.y = -tank_height - 0.9 * (position_i.y + tank_height);
  }
  if (position_i.z > tank_width) {
    position_i.z = tank_width - 0.9 * (position_i.z - tank_width);
  }
  if (position_i.z < -tank_width) {
    position_i.z = -tank_width - 0.9 * (position_i.z + tank_width);
  }

  delta_position_i = position_i - position_pred_i;

  g_delta_positions[3 * i + 0] = delta_position_i.x;
  g_delta_positions[3 * i + 1] = delta_position_i.y;
  g_delta_positions[3 * i + 2] = delta_position_i.z;
}
