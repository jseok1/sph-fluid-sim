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
shared uint l_offsets_bit[RADIX];

uniform uint pass;

// maybe next step: for the other shaders, extract scan and scatter into functions 
// below didn't work - could git reset or debug

void scan() {
  uint l_tid = gl_LocalInvocationID.x;

  uint stride = 2;

  // upsweep (reduction)
  for (uint d = WORKGROUP_SIZE / 2; d > 0; d /= 2) {
    if (l_tid < d) {
      l_offsets_bit[WORKGROUP_SIZE - 1 - (stride * l_tid)] +=
        l_offsets_bit[WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2)];
    }
    stride *= 2;
    barrier();
  }

  if (l_tid == WORKGROUP_SIZE - 1) {
    l_offsets_bit[l_tid] = 0;
  }
  barrier();

  // downsweep
  for (uint d = 1; d < WORKGROUP_SIZE; d *= 2) {
    stride /= 2;
    if (l_tid < d) {
      uint copy = l_offsets_bit[WORKGROUP_SIZE - 1 - (stride * l_tid)];

      l_offsets_bit[WORKGROUP_SIZE - 1 - (stride * l_tid)] +=
        l_offsets_bit[WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2)];
      l_offsets_bit[WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2)] = copy;
    }
    barrier();
  }
}

void split(uint key, uint bit) {
  uint l_tid = gl_LocalInvocationID.x;

  if (l_tid == WORKGROUP_SIZE - 1) {
    false_total = WORKGROUP_SIZE - (l_offsets_bit[l_tid] + bit);
  }
  barrier();

  uint l_offset = bit == 1 ? l_offsets_bit[l_tid] + false_total : l_tid - l_offsets_bit[l_tid];
  barrier();

  l_input[l_offset] = key;
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint nw = gl_NumWorkGroups.x;

  // TODO: it's actually more efficient to handle 4 elements per invocation instead of just 1

  g_offsets[g_tid] = 0;
  l_input[l_tid] = g_input[g_tid];

  // 1. local radix sort on digit
  for (uint i = 0; i < RADIX_SIZE; i++) {
    uint key = l_input[l_tid];
    uint bit = (key >> RADIX_SIZE * pass + i) & 0x1;

    l_offsets_bit[l_tid] = bit;
    barrier();

    scan();
    split(key, bit);
    barrier();
  }

  // 2. local histogram and offsets
  if (l_tid == WORKGROUP_SIZE - 1) {
    for (uint i = 0; i < WORKGROUP_SIZE; i++) {
      uint key = l_input[i];
      uint digit = (key >> RADIX_SIZE * pass) & 0xFF;

      g_offsets[digit * nw + wid]++;
    }
  }
  barrier();

  g_input[g_tid] = l_input[l_tid];
}
