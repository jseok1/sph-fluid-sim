#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer Positions {
  float g_positions[];
};

layout(std430, binding = 7) buffer Velocities {
  float g_velocities[];
};

layout(std430, binding = 8) readonly buffer Densities {
  float g_densities[];
};

layout(std430, binding = 9) readonly buffer Pressures {
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

uniform float deltaTime;
uniform uint nParticles;
uniform uint HASH_TABLE_SIZE;
uniform float mass;
uniform float smoothingRadius;
uniform float lookAhead;
uniform float tankLength;
uniform float tankWidth;
uniform float tankHeight;
uniform float seed;

const float pi = 3.1415926535;
const float gravity = 9.81;
const float viscosity = 0.005;  // 0.001 mass, 0.0 rest density, 0.01 - 0.05 play around

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

vec3 random_dir() {
  return vec3(
    fract(sin(dot(gl_GlobalInvocationID.xy + seed, vec2(12.9898, 78.233))) * 43758.5453),
    fract(sin(dot(gl_GlobalInvocationID.yz + seed, vec2(12.9898, 78.233))) * 43758.5453),
    fract(sin(dot(gl_GlobalInvocationID.zx + seed, vec2(12.9898, 78.233))) * 43758.5453)
  );
}

vec3 grad_spiky(vec3 origin, vec3 position) {
  float distance = distance(origin, position);
  vec3 dir = origin != position ? normalize(origin - position) : normalize(random_dir());
  float b = max(0.0, smoothingRadius - distance);
  return -45.0 / pi / pow(smoothingRadius, 6) * b * b * dir;
}

float lap_vis(vec3 origin, vec3 position) {
  float distance = distance(origin, position);
  float b = max(0.0, smoothingRadius - distance);
  return 45.0 / pi / pow(smoothingRadius, 6) * b;
}

vec3 acceleration(vec3 position_i, vec3 velocity_i, float density_i, float pressure_i) {
  vec3 position_pred_i = position_i + velocity_i * lookAhead;

  vec3 acceleration_i = vec3(0.0);
  for (uint p = 0; p < 27; p++) {
    uint hash = hash(position_pred_i + neighborhood[p] * smoothingRadius);
    uint q = g_cells[hash];
    while (q < nParticles && g_handles_front[q].hash == hash) {
      uint j = g_handles_front[q].index;
      vec3 position_j = vec3(g_positions[3 * j], g_positions[3 * j + 1], g_positions[3 * j + 2]);  // coalesced right?
      vec3 velocity_j = vec3(g_velocities[3 * j], g_velocities[3 * j + 1], g_velocities[3 * j + 2]);
      float density_j = g_densities[j];
      float pressure_j = g_pressures[j];

      vec3 position_pred_j = position_j + velocity_j * lookAhead;

      // acceleration due to pressure
      acceleration_i -= j != gl_GlobalInvocationID.x
                        ? mass * (pressure_i + pressure_j) / (2.0 * density_i * density_j) * grad_spiky(position_pred_i, position_pred_j)
                        : vec3(0.0);

      // acceleration due to viscosity
      acceleration_i += j != gl_GlobalInvocationID.x
                        ? viscosity * mass * (velocity_j - velocity_i) / (density_i * density_j) * lap_vis(position_pred_i, position_pred_j)
                        : vec3(0.0);

      q++;
    }
  }

  // acceleration due to gravity
  acceleration_i.y -= gravity;

  return acceleration_i;
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  uint i = g_tid;
  vec3 position_i = vec3(g_positions[3 * i], g_positions[3 * i + 1], g_positions[3 * i + 2]);
  vec3 velocity_i = vec3(g_velocities[3 * i], g_velocities[3 * i + 1], g_velocities[3 * i + 2]);
  float density_i = g_densities[i];
  float pressure_i = g_pressures[i];

  vec3 acceleration_i = acceleration(position_i, velocity_i, density_i, pressure_i);

  velocity_i += acceleration_i * deltaTime;
  position_i += velocity_i * deltaTime;

  // maybe velocity should be reflected via the surface normal of the wall
  velocity_i.x *= position_i.x < -tankLength || position_i.x > tankLength ? -0.5 : 1.0;
  position_i.x = clamp(position_i.x, -tankLength, tankLength);
  velocity_i.y *= position_i.y < -tankHeight || position_i.y > tankHeight ? -0.5 : 1.0;
  position_i.y = clamp(position_i.y, -tankHeight, tankHeight);
  velocity_i.z *= position_i.z < -tankWidth || position_i.z > tankWidth ? -0.5 : 1.0;
  position_i.z = clamp(position_i.z, -tankWidth, tankWidth);

  g_positions[3 * i] = position_i.x;
  g_positions[3 * i + 1] = position_i.y;
  g_positions[3 * i + 2] = position_i.z;
  g_velocities[3 * i] = velocity_i.x;
  g_velocities[3 * i + 1] = velocity_i.y;
  g_velocities[3 * i + 2] = velocity_i.z;
}
