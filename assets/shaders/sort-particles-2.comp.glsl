#version 460 core

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

layout(std430, binding = 0) buffer ParticlesFrontBuffer {
  Particle g_particles_front[];
};

layout(std430, binding = 5) readonly buffer ParticlesBackBuffer {
  Particle g_particles_back[];
};

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  g_particles_front[g_tid] = g_particles_back[g_tid];
}
