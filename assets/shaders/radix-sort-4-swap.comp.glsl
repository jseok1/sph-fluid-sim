#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 2) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

layout(std430, binding = 3) readonly buffer ParticleHandlesBackBuffer {
  ParticleHandle g_handles_back[];
};

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  // g_handles_front[g_tid] = g_handles_back[g_tid];
}
