#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer PositionsFrontBuffer {
  float g_positions_front[];
};

layout(std430, binding = 2) readonly buffer VelocitiesFrontBuffer {
  float g_velocities_front[];
};

layout(std430, binding = 12) buffer DeltaVelocitiesBuffer {
  float g_delta_velocities[];
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

uvec3 neighborhoods[27] = {
  // clang-format off
  uvec3(-1, -1, -1),
  uvec3(-1, -1,  0),
  uvec3(-1, -1,  1),
  uvec3(-1,  0, -1),
  uvec3(-1,  0,  0),
  uvec3(-1,  0,  1),
  uvec3(-1,  1, -1),
  uvec3(-1,  1,  0),
  uvec3(-1,  1,  1),
  uvec3( 0, -1, -1),
  uvec3( 0, -1,  0),
  uvec3( 0, -1,  1),
  uvec3( 0,  0, -1),
  uvec3( 0,  0,  0),
  uvec3( 0,  0,  1),
  uvec3( 0,  1, -1),
  uvec3( 0,  1,  0),
  uvec3( 0,  1,  1),
  uvec3( 1, -1, -1),
  uvec3( 1, -1,  0),
  uvec3( 1, -1,  1),
  uvec3( 1,  0, -1),
  uvec3( 1,  0,  0),
  uvec3( 1,  0,  1),
  uvec3( 1,  1, -1),
  uvec3( 1,  1,  0),
  uvec3( 1,  1,  1),
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

/**
 * Return the Z-value for a neighborhood in a space-filling Z-curve.
 */
uint neighborhood_hash(uvec3 id) {
  uint hash = (interleave_bits(id.z) << 2) | (interleave_bits(id.y) << 1) | (interleave_bits(id.x) << 0);
  return hash % HASH_TABLE_SIZE;
}

uvec3 neighborhood_id(vec3 position_pred) {
  return uvec3(floor(position_pred / h) + 1e5);
}

float kernel(vec3 position_i, vec3 position_j) {
  // POLY6
  float r = distance(position_i, position_j);
  float residual = max(0.0, h * h - r * r);
  return 315.0 / (64.0 * pi * pow(h, 9)) * residual * residual * residual;
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;
  vec3 position_i = vec3(g_positions_front[3 * i + 0],
                         g_positions_front[3 * i + 1],
                         g_positions_front[3 * i + 2]);
  vec3 velocity_i = vec3(g_velocities_front[3 * i + 0],
                         g_velocities_front[3 * i + 1],
                         g_velocities_front[3 * i + 2]);

  // do I need actual densities here (instead of density_rest)?

  vec3 delta_velocity_i = vec3(0.0);
  for (uint p = 0; p < 27; p++) {
    uvec3 id = neighborhood_id(position_i);
    uint hash = neighborhood_hash(id + neighborhoods[p]);
    uint q = g_particle_handle_offsets[hash];
    while (q < particle_count && g_particle_handles_front[q].hash == hash) {
      uint j = g_particle_handles_front[q].index;
      if (j != i) {
        vec3 position_j = vec3(g_positions_front[3 * j + 0],
                               g_positions_front[3 * j + 1],
                               g_positions_front[3 * j + 2]);
        vec3 velocity_j = vec3(g_velocities_front[3 * j + 0],
                               g_velocities_front[3 * j + 1],
                               g_velocities_front[3 * j + 2]);

        // artificial viscosity
        delta_velocity_i += (velocity_j - velocity_i) * mass * kernel(position_i, position_j);
      }
      q++;
    }
  }
  delta_velocity_i *= 1e-2 / density_rest;

  g_delta_velocities[3 * i + 0] = delta_velocity_i.x;
  g_delta_velocities[3 * i + 1] = delta_velocity_i.y;
  g_delta_velocities[3 * i + 2] = delta_velocity_i.z;
}

