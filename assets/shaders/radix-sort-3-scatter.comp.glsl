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
  uint g_histogram[];
};

struct LogThing {
  uint g_tid;
  uint l_tid;
  uint g_offset;
  uint g_offset_index;
  uint l_offset;
  uint scatter;
};

layout(std430, binding = 5) buffer LogBuffer {
  LogThing log[];
};

uniform uint pass;
uniform uint nParticles;

shared uint l_histogram[RADIX];

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint WORKGROUPS = gl_NumWorkGroups.x;

  ParticleHandle handle = g_handles_front[g_tid];
  uint key = handle.hash;
  uint digit = (key >> 8 * pass) & 0xFF;

  if (l_tid == 0 || digit != ((g_handles_front[g_tid - 1].hash >> 8 * pass) & 0xFF)) {
    l_histogram[digit] = l_tid;
  }
  barrier();

  uint l_offset = l_histogram[digit];
  uint g_offset = 0;

  uint curr_i = digit * WORKGROUPS + wid;
  uint curr_n = uint(ceil(float(nParticles) / WORKGROUP_SIZE) * RADIX);
  uint offset = 0;
  while (curr_n > 1) {
    g_offset += g_histogram[offset + curr_i];
    offset += uint(ceil(float(curr_n) / WORKGROUP_SIZE)) * WORKGROUP_SIZE;
    curr_i = uint(floor(float(curr_i) / WORKGROUP_SIZE));

    curr_n /= WORKGROUP_SIZE;
  }

  // g_offset =
  //   g_histogram[digit * WORKGROUPS + wid] +
  //   g_histogram[nParticles / WORKGROUP_SIZE * RADIX + (digit * WORKGROUPS + wid) / WORKGROUP_SIZE];
  // g_offset = digit * WORKGROUPS + wid;
  // g_offset = g_histogram[digit * WORKGROUPS + wid] +
  //            ((digit * WORKGROUPS + wid) / WORKGROUP_SIZE) * RADIX;  // works fine
  // g_offset = uint(
  //   ((digit * WORKGROUPS + wid) / WORKGROUP_SIZE) * RADIX ==
  //   g_histogram[nParticles / WORKGROUP_SIZE * RADIX + (digit * WORKGROUPS + wid) / WORKGROUP_SIZE]
  // );
  // g_offset = nParticles / WORKGROUP_SIZE * RADIX + (digit * WORKGROUPS + wid) / WORKGROUP_SIZE;
  // g_offset = g_histogram[nParticles / WORKGROUP_SIZE * RADIX + (digit * WORKGROUPS + wid) /
  // WORKGROUP_SIZE]; maybe this part sus on GPUs ^? there is some non-deterministic behavior?
  // https://github.com/baldurk/renderdoc/issues/3550

  // uint hist_idx = digit * WORKGROUPS + wid;
  // uint g_offset = g_histogram[hist_idx] + g_histogram[RADIX * WORKGROUPS + hist_idx /
  // WORKGROUP_SIZE];
  // IT IS THE SCAN ON THE LAST FEW ELEMENTS THAT IS BUGGYYYYYYY!!!!!!

  g_handles_back[l_tid - l_offset + g_offset] = handle;

  log[g_tid].g_tid = g_tid;
  log[g_tid].l_tid = l_tid;
  log[g_tid].g_offset = g_offset;
  log[g_tid].g_offset_index =
    nParticles / WORKGROUP_SIZE * RADIX + (digit * WORKGROUPS + wid) / WORKGROUP_SIZE;
  // log[g_tid].g_offset_1 = g_histogram[hist_idx];
  // log[g_tid].g_offset_2 = g_histogram[RADIX * WORKGROUPS + hist_idx / WORKGROUP_SIZE];
  log[g_tid].l_offset = l_offset;
  log[g_tid].scatter = l_tid - l_offset + g_offset;
}
