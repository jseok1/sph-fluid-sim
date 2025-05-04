#version 460 core

#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 0) readonly buffer ParticlesFrontBuffer {
  Particle g_particles_front[];
};

layout(std430, binding = 5) buffer ParticlesBackBuffer {
  Particle g_particles_back[];
};

layout(std430, binding = 2) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

// idk how this is normally done, so make sure to go consult actual sources
// this also takes up a lot of space
void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  ParticleHandle handle = g_handles_front[g_tid];

  Particle particle = g_particles_front[handle.index];
  g_particles_back[g_tid] = particle;

  handle.index = g_tid;
  g_handles_front[g_tid] = handle;
}
