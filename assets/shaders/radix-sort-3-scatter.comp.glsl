#version 460 core

#define RADIX 256
#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

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

struct LogThing {
  uint g_tid;
  uint l_tid;
  uint g_offset;
  // uint g_offset_1;
  // uint g_offset_2;
  uint l_offset;
  uint scatter;
};

layout(std430, binding = 5) buffer LogBuffer {
  LogThing log[];
};

uniform uint pass;
uniform uint nParticles;

shared uint l_offsets[RADIX];

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint n_workgroups = gl_NumWorkGroups.x;

  ParticleHandle handle = g_handles_front[g_tid];
  uint key = handle.hash;
  uint digit = (key >> 8 * pass) & 0xFF;

  if (l_tid == 0 || digit != ((g_handles_front[g_tid - 1].hash >> 8 * pass) & 0xFF)) {
    l_offsets[digit] = l_tid;
  }
  barrier();

  uint l_offset = l_offsets[digit];
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
  // uint hist_idx = digit * n_workgroups + wid;
  // uint g_offset = g_offsets[hist_idx] + g_offsets[RADIX * n_workgroups + hist_idx / WORKGROUP_SIZE];

  g_handles_back[l_tid - l_offset + g_offset] = handle;

  log[g_tid].g_tid = g_tid;
  log[g_tid].l_tid = l_tid;
  log[g_tid].g_offset = g_offset;
  // log[g_tid].g_offset_1 = g_offsets[hist_idx];
  // log[g_tid].g_offset_2 = g_offsets[RADIX * n_workgroups + hist_idx / WORKGROUP_SIZE];
  log[g_tid].l_offset = l_offset;
  log[g_tid].scatter = l_tid - l_offset + g_offset;
}
