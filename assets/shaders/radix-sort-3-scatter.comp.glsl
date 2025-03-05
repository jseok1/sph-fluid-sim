#version 460 core

#define RADIX 256
#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

struct ParticleHandle {
  uint hash;
  uint offset;
};

layout(std430, binding = 2) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

layout(std430, binding = 3) buffer ParticleHandlesBackBuffer {
  ParticleHandle g_handles_back[];
};

layout(std430, binding = 4) buffer OffsetsBuffer {
  uint g_offsets[];
};

uniform uint pass;
uniform uint sort_n;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint nw = gl_NumWorkGroups.x;

  ParticleHandle handle = g_handles_back[g_tid];
  uint key = handle.hash;
  uint digit = (key >> 8 * pass) & 0xFF;

  uint l_offset;
  // bad (could store within separate SSBO?)  -- better way to calculate in O(1)?
  for (uint i = 0; i < 256; i++) {
    if (((g_handles_back[wid * 256 + i].hash >> 8 * pass) & 0xFF) == digit) {
      l_offset = i;
      break;
    }
  }
  uint g_offset = 0;

  uint curr_i = digit * nw + wid;
  uint curr_n = uint(ceil(float(sort_n) / WORKGROUP_SIZE) * RADIX);
  uint offset = 0;
  while (curr_n > 1) {
    g_offset += g_offsets[offset + curr_i];
    offset += uint(ceil(float(curr_n) / WORKGROUP_SIZE)) * WORKGROUP_SIZE;
    curr_i = uint(floor(float(curr_i) / WORKGROUP_SIZE));

    curr_n /= WORKGROUP_SIZE;
  }

  // is this coalesced???
  g_handles_front[l_tid - l_offset + g_offset] = handle;
}
