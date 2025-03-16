#version 460 core

#define RADIX 256
#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 2) readonly buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

layout(std430, binding = 3) buffer ParticleHandlesBackBuffer {
  ParticleHandle g_handles_back[];
};

layout(std430, binding = 4) readonly buffer OffsetsBuffer {
  uint g_offsets[];
};

layout(std430, binding = 5) buffer LogBuffer {
  uint log[];
};

uniform uint pass;
uniform uint nParticles;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint n_workgroups = gl_NumWorkGroups.x;

  ParticleHandle handle = g_handles_front[g_tid];
  uint key = handle.hash;
  uint digit = (key >> 8 * pass) & 0xFF;

  uint l_offset;
  // bad (could store within separate SSBO?)  -- better way to calculate in O(1)?
  for (uint i = 0; i < 256; i++) {
    if (((g_handles_front[wid * 256 + i].hash >> 8 * pass) & 0xFF) == digit) {
      l_offset = i;
      break;
    }
  }
  uint g_offset = 0;

  uint curr_i = digit * n_workgroups + wid;
  uint curr_n = uint(ceil(float(nParticles) / WORKGROUP_SIZE) * RADIX);
  uint offset = 0;
  while (curr_n > 1) {
    g_offset += g_offsets[offset + curr_i];
    offset += uint(ceil(float(curr_n) / WORKGROUP_SIZE)) * WORKGROUP_SIZE;
    curr_i = uint(floor(float(curr_i) / WORKGROUP_SIZE));

    curr_n /= WORKGROUP_SIZE;
  }

  // is this coalesced???
  // ParticleHandle h;
  // h.hash = 0;
  // h.index = g_tid;
  // g_handles_front[g_tid] = h; // this is fine
  // g_handles_front[l_tid - l_offset + g_offset] = h; // this is not

  // so writing to index g_handles_front[l_tid - l_offset + g_offset] is SUS

  // g_handles_front[g_tid] = handle;  // this is fine
  
  // log looks wrong

  // you're copying the same back buffer thing to here
  // somehow the back buffer is being duplicated, so g_handles_back[g_tid] ends up in duplicates
  g_handles_back[l_tid - l_offset + g_offset] = handle;  // this is not
  log[g_tid] = l_tid - l_offset + g_offset;

  // everything is fine until I ping-pong

  // log[g_tid] = l_tid - l_offset + g_offset; // fine (also global indices are fine)
  // log[l_tid - l_offset + g_offset] = handle.index; // fine 

  // writing to g_handles_front causes duplication in g_handles_front AND g_handles_back
}
