#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer Positions {
  float g_positions[];
};

layout(std430, binding = 7) readonly buffer Velocities {
  float g_velocities[];
};

layout(std430, binding = 8) buffer Densities {
  float g_densities[];
};

layout(std430, binding = 9) buffer Pressures {
  float g_pressures[];
};

layout(std430, binding = 1) readonly buffer CellParticles {
  uint g_cells[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 2) readonly buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
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

uniform uint nParticles;
uniform uint HASH_TABLE_SIZE;
uniform float mass;
uniform float smoothingRadius;
uniform float lookAhead;

// TODO: make uniforms
const float pi = 3.1415926535;
const float density_rest = 0.5;
const float stiffness = 8.31;

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
  uint x = uint((position.x + 5) / smoothingRadius);
  uint y = uint((position.y + 5) / smoothingRadius);
  uint z = uint((position.z + 5) / smoothingRadius);
  uint hash = (interleave_bits(z) << 2) | (interleave_bits(y) << 1) | interleave_bits(x);
  hash = uint(mod(hash, HASH_TABLE_SIZE));  // better if bitwise &
  return hash;
}

float poly6(vec3 origin, vec3 position) {
  float distance = distance(origin, position);
  float b = max(0.0, smoothingRadius * smoothingRadius - distance * distance);
  return 315.0 * b * b * b / (64.0 * pi * pow(smoothingRadius, 9));
}

float density_i(vec3 position_i, vec3 velocity_i) {
  vec3 position_pred_i = position_i + velocity_i * lookAhead;

  float density_i = 0.0;
  for (uint p = 0; p < 27; p++) {
    uint hash = hash(position_pred_i + neighborhood[p] * smoothingRadius);
    uint q = g_cells[hash];
    while (q < nParticles && g_handles_front[q].hash == hash) {
      uint j = g_handles_front[q].index;
      // small optimization: precompute predicted position to only read 3 elements, not 6
      vec3 position_j = vec3(g_positions[3 * j], g_positions[3 * j + 1], g_positions[3 * j + 2]);  // coalesced right?
      vec3 velocity_j = vec3(g_velocities[3 * j], g_velocities[3 * j + 1], g_velocities[3 * j + 2]);

      vec3 position_pred_j = position_j + velocity_j * lookAhead;

      density_i += mass * poly6(position_pred_i, position_pred_j);

      q++;
    }
  }

  return density_i;
}

float pressure(float density_i) {
  return stiffness * (density_i - density_rest);
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  uint i = g_tid;
  vec3 position_i = vec3(g_positions[3 * i], g_positions[3 * i + 1], g_positions[3 * i + 2]);
  vec3 velocity_i = vec3(g_velocities[3 * i], g_velocities[3 * i + 1], g_velocities[3 * i + 2]);

  float density_i = density_i(position_i, velocity_i);
  float pressure_i = pressure(density_i);

  g_densities[i] = density_i;
  g_pressures[i] = pressure_i;
}

