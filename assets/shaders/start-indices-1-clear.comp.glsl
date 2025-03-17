#version 460 core

#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 1) buffer StartIndicesBuffer {
  uint startIndices[];
};

uniform uint mHash;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  startIndices[g_tid] = mHash;  // mark as "empty"
}
