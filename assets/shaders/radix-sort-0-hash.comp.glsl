#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer Positions {
  float g_positions[];
};

layout(std430, binding = 7) readonly buffer Velocities {
  float g_velocities[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 2) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

uniform float lookAhead;
uniform uint HASH_TABLE_SIZE;
uniform float smoothingRadius;

// uint hash(vec3 position) {
  // uint hash = uint(mod(
  //   (uint(floor((position.x + 15.0) / smoothingRadius)) * 73856093) ^
  //     (uint(floor((position.y + 15.0) / smoothingRadius)) * 19349663) ^
  //     (uint(floor((position.z + 15.0) / smoothingRadius)) * 83492791),
  //   HASH_TABLE_SIZE
  // ));
  // return hash;
// }

uint interleaveBits(uint bits) {
  bits &= 0x000003FF;  // keep only 10 bits (3 x 10 bits = 30 bits <= 32 bits)
  bits = (bits | (bits << 16)) & 0x030000FF;  // 00000011 00000000 00000000 11111111
  bits = (bits | (bits << 8))  & 0x0300F00F;  // 00000011 00000000 11110000 00001111
  bits = (bits | (bits << 4))  & 0x030C30C3;  // 00000011 00001100 00110000 11000011
  bits = (bits | (bits << 2))  & 0x09249249;  // 00001001 00100100 10010010 01001001
  return bits;
}

uint hash(vec3 position) {
  // Morton code for locality-preserving hashing
  uint x = uint((position.x + 5) / smoothingRadius);
  uint y = uint((position.y + 5) / smoothingRadius);
  uint z = uint((position.z + 5) / smoothingRadius);
  uint hash = (interleaveBits(z) << 2) | (interleaveBits(y) << 1) | interleaveBits(x);
  // so here I could modulo and use the hash table or binary search
  // take some example morton codes, modulo then see what happens. My guess - it just chops off the
  // prefix bits? Implement with bitwise &? Or you could shift >> << (for powers of 2).

  // morton codes here can be 32 bits. Anything outside will conflict.
  // x, y, z coords go up to 1023 before wrapping
  hash = uint(mod(hash, HASH_TABLE_SIZE));  // better if bitwise &
  return hash;
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  ParticleHandle handle = g_handles_front[g_tid];

  uint i = handle.index;
  vec3 position_i = vec3(g_positions[3 * i], g_positions[3 * i + 1], g_positions[3 * i + 2]);
  vec3 velocity_i = vec3(g_velocities[3 * i], g_velocities[3 * i + 1], g_velocities[3 * i + 2]);

  handle.hash = hash(position_i + velocity_i * lookAhead);
  g_handles_front[g_tid] = handle;
}
