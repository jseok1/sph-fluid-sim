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
  Particle particles[];
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

// layout(std430, binding = 5) buffer LogBuffer {
//   uint log[];
// };

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

uniform uint nParticles;
uniform uint HASH_TABLE_SIZE;
uniform float smoothingRadius;
uniform float lookAhead;

// TODO: make uniforms
const float pi = 3.1415926535;
const float restDensity = 0.0;
const float gas = 8.31;

uint hash(vec3 position) {
  uint hash = uint(mod(
    (uint(floor((position.x + 15.0) / smoothingRadius)) * 73856093) ^
      (uint(floor((position.y + 15.0) / smoothingRadius)) * 19349663) ^
      (uint(floor((position.z + 15.0) / smoothingRadius)) * 83492791),
    HASH_TABLE_SIZE
  ));
  return hash;
}

float poly6(vec3 origin, vec3 position) {
  float distance = distance(origin, position);
  float b = max(0.0, smoothingRadius * smoothingRadius - distance * distance);
  return 315.0 * b * b * b / (64.0 * pi * pow(smoothingRadius, 9));
}

// TODO: remove particles[i] --> fetches into global memory are SLOW
float density(Particle particle) {
  vec3 position = vec3(particle.position[0], particle.position[1], particle.position[2]);
  vec3 velocity = vec3(particle.velocity[0], particle.velocity[1], particle.velocity[2]);

  vec3 position_pred = position + velocity * lookAhead;

  float density = 0.0;
  for (uint j = 0; j < 27; j++) {
    uint hash = hash(position_pred + neighborhood[j] * smoothingRadius);
    uint k = g_hashIndices[hash];
    while (k < nParticles && g_handles_front[k].hash == hash) {
      Particle neighbor = particles[g_handles_front[k].index];
      vec3 neighbor_position =
        vec3(neighbor.position[0], neighbor.position[1], neighbor.position[2]);
      vec3 neighbor_velocity =
        vec3(neighbor.velocity[0], neighbor.velocity[1], neighbor.velocity[2]);

      vec3 neighbor_position_pred = neighbor_position + neighbor_velocity * lookAhead;

      density += neighbor.mass * poly6(position_pred, neighbor_position_pred);

      k++;
    }
  }

  return density;
}

float volume(Particle particle) {
  return particle.mass / particle.density;
}

float pressure(Particle particle) {
  return gas * (particle.density - restDensity);
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  Particle particle = particles[g_tid];

  particle.density = density(particle);
  particle.volume = volume(particle);
  particle.pressure = pressure(particle);

  particles[g_tid] = particle;
}

// what if the predicted position goes out of bounds?
