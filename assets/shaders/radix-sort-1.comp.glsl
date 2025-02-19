#version 460 core

#define RADIX 256
#define RADIX_SIZE 8  // 8-bit radix (2⁸ = 256)
#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 2) buffer InputBuffer {
  uint g_input[];
};

layout(std430, binding = 3) buffer OutputBuffer {
  uint g_output[];
};

layout(std430, binding = 4) buffer HistogramBuffer {
  uint g_offsets[];
};

shared uint false_total;
shared uint l_input[WORKGROUP_SIZE];
shared uint l_bit_flags[RADIX];

uniform uint pass;

uint scan() {
  uint l_tid = gl_LocalInvocationID.x;

  uint true_before = 0;

  // not the worst since bounded by 256 but ideally also parallelize
  for (uint i = 0; i < l_tid; i++) {
    true_before += l_bit_flags[i];  // how to make scan faster? -- could also just use l_input
  }

  return true_before;
}

uint split(uint bit) {
  uint l_tid = gl_LocalInvocationID.x;

  // (1) Count ’True’ predicates held by lower-numbered threads
  uint true_before = scan();

  // (2) Last thread calculates total number of ’False’ predicates
  if (l_tid == WORKGROUP_SIZE - 1) {
    false_total = WORKGROUP_SIZE - (true_before + bit);
  }
  barrier();

  // (3) Compute and return the ’rank’ for this thread
  return bit == 1 ? true_before + false_total : l_tid - true_before;  // weird there's no truthy
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint nw = gl_NumWorkGroups.x;

  // TODO: it's actually more efficient to handle 4 elements per invocation instead of just 1

  g_offsets[g_tid] = 0;
  l_input[l_tid] = g_input[g_tid];  // copy into shared memory

  // 1. local radix sort on digit
  for (uint i = 0; i < RADIX_SIZE; i++) {
    uint key = l_input[l_tid];
    uint bit = (key >> RADIX_SIZE * pass + i) & 0x1;

    l_bit_flags[l_tid] = bit;
    barrier();

    uint l_dst_idx = split(bit);
    barrier();

    l_input[l_dst_idx] = key;
    barrier();
  }

  // 2. local histogram and offsets
  if (l_tid == WORKGROUP_SIZE - 1) {
    for (uint i = 0; i < 256; i++) {
      uint key = l_input[i];
      uint digit = (key >> RADIX_SIZE * pass) & 0xFF;

      g_offsets[digit * nw + wid]++;
    }
  }
  barrier();

  g_input[g_tid] = l_input[l_tid];
}
