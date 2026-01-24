#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer PositionsBuffer {
  float g_positions[];
};

layout(std430, binding = 1) readonly buffer VelocitiesBuffer {
  float g_velocities[];
};

layout(std430, binding = 4) buffer DeltaVelocitiesBuffer {
  float g_delta_velocities[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 6) readonly buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_particle_handles[];
};

layout(std430, binding = 8) readonly buffer ParticleHandleOffsetsBuffer {
  uint g_particle_handle_offsets[];
};

layout(std430, binding = 10) buffer VorticitiesBuffer {
  float g_vorticities[];
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

vec3 grad_kernel(vec3 position_i, vec3 position_j) {
  // SPIKY
  float r = distance(position_i, position_j);
  vec3 direction = r > 1e-8 ? normalize(position_i - position_j) : vec3(0.0);
  float residual = max(0.0, h - r);
  return -45.0 / (pi * pow(h, 6)) * residual * residual * direction;
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;
  vec3 position_i = vec3(g_positions[3 * i + 0],
                         g_positions[3 * i + 1],
                         g_positions[3 * i + 2]);
  vec3 velocity_i = vec3(g_velocities[3 * i + 0],
                         g_velocities[3 * i + 1],
                         g_velocities[3 * i + 2]);

  // do I need actual densities here (instead of density_rest)?
  vec3 delta_velocity_i = vec3(0.0);
  vec3 vorticity_i = vec3(0.0);
  for (uint p = 0; p < 27; p++) {
    uvec3 id = neighborhood_id(position_i);
    uint hash = neighborhood_hash(id + neighborhoods[p]);
    uint q = g_particle_handle_offsets[hash];
    while (q < particle_count && g_particle_handles[q].hash == hash) {
      uint j = g_particle_handles[q].index;
      if (j != i) {
        vec3 position_j = vec3(g_positions[3 * j + 0],
                               g_positions[3 * j + 1],
                               g_positions[3 * j + 2]);
        vec3 velocity_j = vec3(g_velocities[3 * j + 0],
                               g_velocities[3 * j + 1],
                               g_velocities[3 * j + 2]);

        vec3 velocity_ij = velocity_j - velocity_i;

        // artificial viscosity
        delta_velocity_i += velocity_ij * kernel(position_i, position_j);

        // vorticity confinement
        vorticity_i += cross(velocity_ij, -grad_kernel(position_i, position_j));
      }
      q++;
    }
  }
  delta_velocity_i *= mass / density_rest;
  vorticity_i *= mass / density_rest;

  delta_velocity_i *= 1e-2;

  g_delta_velocities[3 * i + 0] = delta_velocity_i.x;
  g_delta_velocities[3 * i + 1] = delta_velocity_i.y;
  g_delta_velocities[3 * i + 2] = delta_velocity_i.z;

  g_vorticities[3 * i + 0] = vorticity_i.x;
  g_vorticities[3 * i + 1] = vorticity_i.y;
  g_vorticities[3 * i + 2] = vorticity_i.z;
}

