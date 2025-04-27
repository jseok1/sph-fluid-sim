#version 460 core

#define RADIX 256
#define RADIX_SIZE 8        // 8-bit radix (2⁸ = 256)
#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

struct Particle {
  float mass;
  float density;
  float volume;
  float pressure;
  float position[3];
  float velocity[3];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 0) readonly buffer ParticlesBuffer {
  Particle g_particles[];
};

layout(std430, binding = 2) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

uniform float lookAhead;
uniform uint HASH_TABLE_SIZE;
uniform float smoothingRadius;

uint hash(vec3 position) {
  uint hash = uint(mod(
    (uint(floor((position.x + 15.0) / smoothingRadius)) * 73856093) ^
      (uint(floor((position.y + 15.0) / smoothingRadius)) * 19349663) ^
      (uint(floor((position.z + 15.0) / smoothingRadius)) * 83492791),
    HASH_TABLE_SIZE
  ));
  return hash;
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  ParticleHandle handle = g_handles_front[g_tid];
  Particle particle = g_particles[handle.index];
  vec3 position = vec3(particle.position[0], particle.position[1], particle.position[2]);
  vec3 velocity = vec3(particle.velocity[0], particle.velocity[1], particle.velocity[2]);
  handle.hash = uint(position + velocity * lookAhead); // hash(position + velocity * lookAhead);
  g_handles_front[g_tid] = handle;
}
