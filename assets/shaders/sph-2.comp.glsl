#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

struct Particle {
  float mass;
  float density;
  float volume;
  float pressure;
  float position[3];
  float velocity[3];
};

layout(std430, binding = 0) buffer Particles {
  Particle g_particles[];
};

layout(std430, binding = 1) buffer HashIndicesBuffer {
  uint g_hashIndices[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 2) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

// struct LogObject {
//   float x;
//   float y;
//   float z;
// };

// layout(std430, binding = 5) buffer LogBuffer {
//   LogObject log[];
// };

uniform float deltaTime;
uniform uint nParticles;
uniform uint HASH_TABLE_SIZE;
uniform float smoothingRadius;
uniform float lookAhead;
uniform float tankLength;
uniform float tankWidth;
uniform float tankHeight;
uniform float time;

const float pi = 3.1415926535;
const float gravity = 9.81;
const float viscosity = 0.005;  // 0.001 mass, 0.0 rest density, 0.01 - 0.05 play around

// clang-format off
vec3 neighborhood[27] = {
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
};
// clang-format on

// uint hash(vec3 position) {
//   uint hash = uint(mod(
//     (uint(floor((position.x + 15.0) / smoothingRadius)) * 73856093) ^
//       (uint(floor((position.y + 15.0) / smoothingRadius)) * 19349663) ^
//       (uint(floor((position.z + 15.0) / smoothingRadius)) * 83492791),
//     HASH_TABLE_SIZE
//   ));
//   return hash;
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
  hash = uint(mod(hash, HASH_TABLE_SIZE));  // better if bitwise &
  return hash;
}

vec3 random_dir() {
  return vec3(
    fract(sin(dot(gl_GlobalInvocationID.xy + time, vec2(12.9898, 78.233))) * 43758.5453),
    fract(sin(dot(gl_GlobalInvocationID.yz + time, vec2(12.9898, 78.233))) * 43758.5453),
    fract(sin(dot(gl_GlobalInvocationID.zx + time, vec2(12.9898, 78.233))) * 43758.5453)
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

vec3 acceleration(Particle particle) {
  vec3 position = vec3(particle.position[0], particle.position[1], particle.position[2]);
  vec3 velocity = vec3(particle.velocity[0], particle.velocity[1], particle.velocity[2]);

  vec3 position_pred = position + velocity * lookAhead;

  vec3 acceleration = vec3(0.0);
  for (uint j = 0; j < 27; j++) {
    uint hash = hash(position_pred + neighborhood[j] * smoothingRadius);
    uint k = g_hashIndices[hash];
    while (k < nParticles && g_handles_front[k].hash == hash) {
      Particle neighbor = g_particles[g_handles_front[k].index];
      vec3 neighbor_position =
        vec3(neighbor.position[0], neighbor.position[1], neighbor.position[2]);
      vec3 neighbor_velocity =
        vec3(neighbor.velocity[0], neighbor.velocity[1], neighbor.velocity[2]);

      vec3 neighbor_position_pred = neighbor_position + neighbor_velocity * lookAhead;

      // TODO: THIS CONDITION g_handles_front[k].index != gl_GlobalInvocationID.x IS VERY IMPORTANT
      // -> WHY?

      /** acceleration due to pressure */
      acceleration -= g_handles_front[k].index != gl_GlobalInvocationID.x
                        ? neighbor.volume * (particle.pressure + neighbor.pressure) /
                            (2.0 * particle.density) *
                            grad_spiky(position_pred, neighbor_position_pred)
                        : vec3(0.0);

      /** acceleration due to viscosity */
      acceleration += g_handles_front[k].index != gl_GlobalInvocationID.x
                        ? viscosity * neighbor.volume * (neighbor_velocity - velocity) /
                            particle.density * lap_vis(position_pred, neighbor_position_pred)
                        : vec3(0.0);

      k++;
    }
  }

  /** acceleration due to gravity */
  acceleration.y -= gravity;

  return acceleration;
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  Particle particle = g_particles[g_tid];

  vec3 position = vec3(particle.position[0], particle.position[1], particle.position[2]);
  vec3 velocity = vec3(particle.velocity[0], particle.velocity[1], particle.velocity[2]);

  // 1. update velocity (Euler integration)
  velocity += acceleration(particle) * deltaTime;

  // 2. update position (Euler integration)
  position += velocity * deltaTime;

  // maybe velocity should be reflected via the surface normal of the wall
  velocity.x *= position.x < -tankLength || position.x > tankLength ? -0.5 : 1.0;
  position.x = clamp(position.x, -tankLength, tankLength);
  velocity.y *= position.y < -tankHeight || position.y > tankHeight ? -0.5 : 1.0;
  position.y = clamp(position.y, -tankHeight, tankHeight);
  velocity.z *= position.z < -tankWidth || position.z > tankWidth ? -0.5 : 1.0;
  position.z = clamp(position.z, -tankWidth, tankWidth);

  particle.position[0] = position.x;
  particle.position[1] = position.y;
  particle.position[2] = position.z;
  particle.velocity[0] = velocity.x;
  particle.velocity[1] = velocity.y;
  particle.velocity[2] = velocity.z;

  g_particles[g_tid] = particle;
}
