#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 4) readonly buffer PredictedPositionsBuffer {
  float g_positions_pred[];
};

layout(std430, binding = 6) buffer MultipliersBuffer {
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

const float pi = 3.1415926535;

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
  uint hash = (interleave_bits(z) << 2) | (interleave_bits(y) << 1) | (interleave_bits(x) << 0);
  hash = uint(mod(hash, HASH_TABLE_SIZE));  // better if bitwise &
  return hash;
}

float kernel(vec3 position_i, vec3 position_j) {
  // POLY6
  float r = distance(position_i, position_j);
  float residual = max(0.0, h * h - r * r);
  return 315.0 / (64.0 * pi * pow(h, 9)) * residual * residual * residual;
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

  float density_i = mass * kernel(position_pred_i, position_pred_i);
  vec3 grad_constraint_i = vec3(0.0);
  float summed_squared_grad_constraints = 0.0;

  for (uint p = 0; p < 27; p++) {
    uint hash = hash(position_pred_i + neighborhood[p] * h);
    uint q = g_particle_handle_offsets[hash];
    while (q < particle_count && g_particle_handles_front[q].hash == hash) {
      uint j = g_particle_handles_front[q].index;
      if (j != i) {
        vec3 position_pred_j = vec3(g_positions_pred[3 * j + 0],
                                    g_positions_pred[3 * j + 1],
                                    g_positions_pred[3 * j + 2]);

        density_i += mass * kernel(position_pred_i, position_pred_j);

        vec3 grad_constraint_j = mass * grad_kernel(position_pred_i, position_pred_j);
        grad_constraint_i += grad_constraint_j;

        summed_squared_grad_constraints += dot(grad_constraint_j, grad_constraint_j);
      }
      q++;
    }
  }

  summed_squared_grad_constraints += dot(grad_constraint_i, grad_constraint_i);
  summed_squared_grad_constraints /= density_rest * density_rest;

  float constraint_i = density_i / density_rest - 1.0;
  float multiplier_i = -constraint_i / (summed_squared_grad_constraints + 1e-5);

  g_multipliers[i] = multiplier_i;

  g_debug[i] = density_i;
}
