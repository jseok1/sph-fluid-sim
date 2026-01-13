#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 4) readonly buffer PredictedPositionsBuffer {
  float g_positions_pred[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 7) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_particle_handles_front[];
};

uniform uint particle_count;
uniform uint HASH_TABLE_SIZE;
uniform float h;

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

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  ParticleHandle handle = g_particle_handles_front[g_tid];

  uint i = handle.index;
  vec3 position_pred_i = vec3(g_positions_pred[3 * i + 0],
                              g_positions_pred[3 * i + 1],
                              g_positions_pred[3 * i + 2]);

  handle.hash = hash(position_pred_i);
  g_particle_handles_front[g_tid] = handle;
}
