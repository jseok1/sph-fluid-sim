#version 460 core

#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 1) buffer HashIndicesBuffer {
  uint g_hashIndices[];
};

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 2) readonly buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  uint key = g_handles_front[g_tid].hash;

  if (g_tid == 0 || key != g_handles_front[g_tid - 1].hash) {
    g_hashIndices[key] = g_tid;
  }
}
