#version 460 core

#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 6) readonly buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_particle_handles[];
};

layout(std430, binding = 8) buffer ParticleHandleOffsetsBuffer {
  uint g_particle_handle_offsets[];
};

uniform uint particle_count;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  if (g_tid >= particle_count) return;

  uint i = g_tid;

  uint hash = g_particle_handles[i].hash;

  if (i == 0 || hash != g_particle_handles[i - 1].hash) {
    g_particle_handle_offsets[hash] = i;
  }
}
